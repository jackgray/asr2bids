#!/bin/env bash
# Takes full path to folder containing untranscribed audio, and generates json transcriptions in the same folder

# Ensure Whisper docker service is running
# docker run -d -p 9000:9000 -e ASR_MODEL=large onerahmet/openai-whisper-asr-webservice:latest 

input_files=$(ls $1)
printf "\n\nTranscribing files in supplied path: $infiles"

pushd $1
for audiofile in $input_files; do
    # Make name for output file
    output_json=$(echo "${audiofile}" | cut -d'.' -f 1)_header-raw.json
    
    # Make REST call to Whisper web server (but only if the transcript doesnt already exist)
    if [[ ! -f "$output_json" ]] || [[ $(cat "${output_json}" | wc -l) < 3 ]]; then
        printf "\n${output_json} contents: \n\n"
        cat $output_json
        
        # Chop header content
        printf "\nCutting beginning of file to save time transcribing...\n"
        clipname="audiotempfile.mp3"        
        ffmpeg -ss 00:00:00 -i $audiofile -to 00:00:30 -y tempaudiofile.mp3

        # Send clip to Whisper docker service w/ REST API 
        curl -X 'POST'   \
        'http://localhost:9000/asr?task=transcribe&language=en&output=json'   \
        -H 'accept: application/json'   \
        -H 'Content-Type: multipart/form-data'   \
        -F 'audio_file=@tempaudiofile.mp3;type=audio/mpeg' > ${output_json}
    fi

done
popd