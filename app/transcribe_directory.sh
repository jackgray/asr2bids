#!/bin/env bash
# This script transcribes audio files using the Whisper service

# Check if required arguments are provided
if [ "$#" -lt 3 ]; then
    echo "Usage: $0 <parent_directory> <ASR_model> <clip_duration>"
    exit 1
fi

# Define constants and variables
parentdir="$1"
ASR_MODEL="$2"
CLIP_DUR="$3"
MIN_FILE_SIZE=1000
MIN_AUDIO_FILE_SIZE=1000
SERVICE_NAME="whisper_webservice_${ASR_MODEL}"

# Function to transcribe audio using Whisper
call_whisper() {
    local audiofile="$1"
    local output_json="$2"

    # Ensure transcript doesn't already exist
    if [[ -f "$output_json" ]] && (( $(wc -c < "$output_json") < $MIN_FILE_SIZE )); then
        echo "JSON file is either missing or incomplete. Re-attempting transcription..."
    elif [[ -f "$output_json" ]]; then
        echo "Found header file with more than $MIN_FILE_SIZE bytes. Skipping transcription."
        continue
    else
        echo "No JSON file found. Transcribing audio file: $audiofile"
    fi
    


    # If CLIP_DURATION is not provided, transcribe the entire audio file
    if [ -z "$CLIP_DUR" ]; then
        printf "\nTranscribing entire audio file...\n"
        # Transcribe entire audio file
        ffmpeg -i "$audiofile" -vn -ar 44100 -y tempaudiofile.mp3
    else
        # If CLIP_DURATION is provided, transcribe a clip of the specified duration
        printf "\nTranscribing a clip of duration ${CLIP_DUR}...\n"
        # Chop header content
        printf "\nCutting beginning of file to save time transcribing...\n"
        printf "\n\n************ ffmpeg: making temp clip *******************\n"
        printf "\n ${mp3_fullpath} \n"
        # Transcribe specified clip duration
        ffmpeg -ss 00:00:00 -i "$audiofile" -to "$CLIP_DUR" -y tempaudiofile.mp3
    fi

    printf "\n\n*********************************************************\n"


    # Call Whisper docker service to transcribe
    curl -X POST \
        "${WHISPER_ENDPOINT}/asr?task=transcribe&language=en&output=json" \
        -H 'accept: application/json' \
        -H 'Content-Type: multipart/form-data' \
        -F 'audio_file=@tempaudiofile.mp3;type=audio/mpeg' > "$output_json"

    # Confirm transcription success
    if [[ $(wc -c < "$output_json") == 0 ]]; then
        echo "Transcription failed or resulted in empty file: $output_json"
        rm "$output_json"
    else
        echo "Transcription successful! Saved to: $output_json"
    fi
}

# Main script
echo "Transcribing files in supplied path: $parentdir"
pushd "$parentdir" || exit

for audiofile_wcaps in $(find $basepath -type f -not -regex $narcid_regex); do
    # Check if file is audio and not already transcribed
    filetype=$(echo "${audiofile_wcaps##*.}" | tr '[:upper:]' '[:lower:]')
    if [[ "$filetype" != 'json' ]]; then
        afile=$(basename "$audiofile_wcaps")
        output_json="${afile%.*}.json"

        # Ensure audio file exists and meets minimum size
        if (( $(wc -c < "$audiofile") < $MIN_AUDIO_FILE_SIZE )); then
            echo "Invalid audio file: $audiofile. Skipping transcription."
            echo "$audiofile" >> "$parentdir"/skipped.log
            continue
        fi

        # Check if audio is stereo and split if necessary
        if ffprobe -i "$audiofile" |& grep stereo; then
            mp3left_fullpath="${parentdir}/${afile%.*}_ch-1.mp3"
            mp3right_fullpath="${parentdir}/${afile%.*}_ch-2.mp3"
            ffmpeg -i "$audiofile" -vn -ar 44100 -map_channel 0.0.0 "$mp3left_fullpath" -map_channel 0.0.1 "$mp3right_fullpath"
            call_whisper "$mp3left_fullpath" "${mp3left_fullpath%.*}.json"
            call_whisper "$mp3right_fullpath" "${mp3right_fullpath%.*}.json"
        else

            # Transcribe with whisper REST service
            call_whisper "$audiofile" "$output_json"
        fi

        # Confirm sucess, delete empty json files
        if (( $(wc -c < "${output_json}") == 0 )); then
            printf "\n\nDetected empty file: ${output_json}\n"
            rm "$output_json"
            continue
            # If it didn't fail, move the original file to complete
        else 
            printf "\n\nTranscribe successful!\n"
            # mkdir -p "$parentdir"/completed && mv $audiofile "$parentdir"/completed
        fi

    else
        echo "Skipping JSON file: $audiofile_wcaps"
    fi
done

popd || exit
