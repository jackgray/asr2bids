#!/bin/env bash
# Takes full path to folder containing untranscribed audio, and generates json transcriptions in the same folder

# Supply path to a directory containing audio files 
parentdir=$1
input_files=$(ls $parentdir/*)

#*****************************************
#********* SETUP WHISPER *****************
#*****************************************

asr_model=tiny
service_name=whisper_webservice_${asr_model}
# Stop running whisper service and start with selected model
# docker run --name $service_name -d -p 9000:9000 -e ASR_MODEL=${asr_model} onerahmet/openai-whisper-asr-webservice:latest \
docker start $service_name || echo "Docker service is already running"

call_whisper () {
    infile=$1
    output_json=$2
    #********************************************************************
    #****************** Ensure transcript doesn't already exist *********
    #******************************************************************** 

    printf "\n\nMaking sure the json file ${output_json} doesn't already have valid version...\n\n"
    jsonsize=$( wc -c < "${output_json}") # followback function
    echo "Filesize: ${jsonsize}"
    if [[ -f "$output_json" ]] && (( $jsonsize < 1000 )); then
        needs_transcribing=true
        printf "\n\nNo json file or it's too small to have all the expected info; re-attempting transcription..."
        printf "\nFile contents: \n"
        cat "$output_json"
    
    elif [[ -f "$output_json" ]] && (( $jsonsize > 999 )); then
        needs_transcribing=false
        printf "\n\nFound header file with more than 5 lines.\n Skipping it."
        cat "$output_json"
        continue
    elif [[ ! -f "$output_json" ]]; then
        needs_transcribing=true
        printf "\n\nNo json file found, so we will transcribe the audio file ${infile} and create one.\n"
    else 
        printf "\n\nUnknown state of ${output_json}...\nTranscribing anyway.\n(Dumping contents):\n"
        cat "$output_json"
        needs_transcribing=true
    fi
    
    if [[ "$needs_transcribing" == 'true' ]]; then
                                
        #******************************************************
        #****************** MAKE SHORT CLIP *******************
        #******************************************************
        # Chop header content
        printf "\nCutting beginning of file to save time transcribing...\n"
        # pushd "$parentdir"
        printf "\n\n************ ffmpeg: making temp clip *******************\n"
        printf "\n ${mp3_fullpath} \n"
        ffmpeg -ss 00:00:00 -i $infile -to 00:00:30 -y tempaudiofile.mp3
        printf "\n\n*********************************************************\n"
        #******************************************************
        #****************** CALL WHISPER DOCKER SERVICE *******
        #********************************* (TRANSCRIBE) *******
        #******************************************************
        touch "$output_json"
        printf "\n\n Calling whisper service \n"
        # Send clip to Whisper docker service w/ REST API 
        curl -X 'POST'   \
        'http://localhost:9000/asr?task=transcribe&language=en&output=json'   \
        -H 'accept: application/json'   \
        -H 'Content-Type: multipart/form-data'   \
        -F 'audio_file=@tempaudiofile.mp3;type=audio/mpeg' > ${output_json}
        

        #****************************************************
        #************* CONFIRM SUCESS ***********************
        #****************************************************
        if (( $(wc -c < "${output_json}") == 0 )); then
            printf "\n\nDetected empty file: ${output_json}\n"
            rm "$output_json"
            return continue
            # If it didn't fail, xxxxxxmove the original file to complete
        else 
            printf "\n\nTranscribe successful!\n"
            # mkdir -p "$parentdir"/completed && mv $audiofile "$parentdir"/completed
        fi
    else 
        printf "\n\nDetected existing json file with possibly valid content - skipping \n" #(Dumping contents): \n"
        # cat "$output_json"
        echo "$audiofile" >> "$parentdir"/skip.log
    fi
}

printf "\n********************************************\nTranscribing files in supplied path: $parentdir\n*****************************************************\n"
pushd "$parentdir"

for audiofile_wcaps in $input_files; do
    # Break up folders and filenames into parts
    printf "\n\n\n--------------------------NEXT FILE-----------------------------\n\n"
    printf "\n\nInspecting ${audiofile_wcaps}\n\n"
    
    # Make all file extensions lowercase
    filetype=$(echo "${audiofile_wcaps}" | cut -d'.' -f 2 | tr '[:upper:]' '[:lower:]')
    printf "\n\nDetected filetype: ${filetype}\n"

    if [[ "$filetype" == 'json' ]]; then
        printf "\n\nDetected json file. Skipping.\n"
        continue
    fi

    afile=$(echo ${audiofile_wcaps} | rev | cut -d'/' -f 1 | rev )
    afile_base=$(echo "${afile}" | cut -d'.' -f 1)
    audiofile="$parentdir"/"$afile_base"."$filetype"
    # Make all file extensions lowercase (changes filename to lowercase extension)
    mv "$audiofile_wcaps" "$audiofile"
    # update audio file name after changing it
    afile=$(echo ${audiofile} | rev | cut -d'/' -f 1 | rev )    
    
    printf "\n\nParent dir: ${parentdir} \n"
    printf "\nJust the file: ${afile}\n"

    # Make name for output file
    output_json=$(echo "${audiofile}" | cut -d'.' -f 1).json    # Chop everything at the '.' and add new extension
    printf "\n\nSaving header file as $output_json\n"
    # convert if not mp3
    
    
    # If the file doesn't pass through below logic, it is already an mp3
    mp3filename=${afile_base}.mp3
    mp3_fullpath=${parentdir}/${mp3filename}


    #*********************************************
    #************* MP3 CONVERSION ****************
    #*********************************************
    # If it's not mp3 assume it's an audio file we want to convert
    # Or if mp3 exists but is small, try to convert again
    if [[ "$filetype" != 'mp3' ]]; then
        printf "\n\nThis is not an MP3 file, or it is empty -- ${audiofile}. Using ffmpeg to convert it.\n"
        printf "\nSaving file as ${mp3_fullpath}\n"
        
        if [[ -f "$mp3_fullpath" ]] && (( $(wc -c < "${mp3_fullpath}") < 2000 )); then
            printf "\nFound matching mp3 file, but it's less than 2kb so it may be corrupt. Removing it and re-converting.\n"
            rm "$mp3_fullpath"
        elif [[ -f "$mp3_fullpath" ]] && (( $(wc -c < "${mp3_fullpath}") > 1999 )); then
            printf "\nFile has already been converted to MP3. Moving on to transcription.\n"
            skip_mp3=true
        fi

        # Sort out docker version -- more reliable
        # docker run --rm -it \
        #     -v $1:/config \
        #     linuxserver/ffmpeg \
        #     -i /config/"$afile" \
        #     -c:v libx264 \
        #     -vn \
        #     -c:a copy \
        #     /config/"$afile_base".mp3
        if [[ $skip_mp3 != true ]]; then
            printf "\n\nConverting to MP3 using local ffmpeg for development --switch to docker container later--...\n"
            #*********** MP3 Convert ********************
            printf "\n\n************ ffmpeg: mp3 conversion - ${mp3_fullpath} *******************\n"
            ffmpeg -i "$audiofile" -vn -ar 44100 "$mp3_fullpath" # converts any file to mp3 at 44.1 kHz
            printf "\n\n*************************************************************************\n"

        else 
            printf "\n\nMP3 file already exists for this file. Skipping conversion and moving original to completed folder\n\n"
            mkdir -p "$parentdir"/converted && mv "$audiofile" "$parentdir"/converted
        fi
    else printf "\n\nFile does not appear to need mp3 conversion.\n"
    fi

    # Should now only be using mp3_fullpath. audiofile var is the original unconverted file.        
    #****************************************************
    #************* CONFIRM MP3 EXISTS *******************
    #****************************************************
    # IF not saved successfully (file is non-empty), skip to next audio file and log the problem file
    # alsdfjlasdf move original (non-mp3) version out of the way
    if (( ! $(wc -c < "${mp3_fullpath}") > 1000 )); then
        printf "\n\nCouldt get a valid mp3 file. Skipping to next in list.\n"
        echo "$mp3_fullpath" >> "$parentdir"/skipped.log
        printf "\nRemoving empty file\n"
        rm "$mp3_fullpath"
        continue
    fi

    #*********************************************
    #************* STEREO SPLITTING **************
    #*********************************************
    # Check if the current file has already been split
    # split_detection=$(echo ${afile_base} | rev | cut -d'_' -f1 | rev)
    # if [[ "$split_detection" == 'left' ]] || [[ "$split_detection" == 'right' ]] || [[ -f "${parentdir}/${afile_base}_left.mp3" ]] || [[ -f "${parentdir}/${afilebase}_right.mp3" ]]; then
    #     is_split=true
    # else is_split=false
    # fi
    printf "\n\nChecking if this file is stereo or mono: ${mp3_fullpath}\n\n"
    if ffprobe -i $mp3_fullpath |& grep stereo; then
        isMono=false
        printf '\nFile is in stereo. Splitting.\n'
    else 
        printf "\n\nFile is already mono."
        isMono=true
    fi

    mp3left_fullpath="${parentdir}/${afile_base}"_left.mp3
    mp3right_fullpath="${parentdir}/${afile_base}"_right.mp3
    if [[ "$isMono" == 'false' ]]; then

        if [[ -f "$mp3left_fullpath" ]] && (( $(wc -c < ${mp3left_fullpath}) < 1000 )); then
            printf "\n\nDetected audio file less than 1kb. ${mp3left_fullpath} Assuming it's corrupt and deleting it.\n"
            rm "$mp3left_fullpath"
        fi
        if [[ -f "$mp3right_fullpath" ]] && (( $(wc -c < ${mp3right_fullpath}) < 1000 )); then
            printf "\n\nDetected audio file less than 1kb. \n${mp3right_fullpath}\n Assuming it's corrupt and deleting it.\n"
            rm "$mp3right_fullpath"
        fi
        # Try to split the audio file 
        # docker run --rm -it \
        #     -v $1:/config \
        #     linuxserver/ffmpeg \
        #     -i /config/"$infile" \
        #     -c:v libx264 \
        #     -vn \
        #     -c:a copy \
        #     /config/"$afile_base".mp3
        


        #**********  Split *****************
        if [[ ! -f "$mp3left_fullpath" ]] && [[ ! -f "$mp3right_fullpath" ]]; then
            printf "\n\n************ ffmpeg: Splitting *******************\n"
            printf "\n${mp3_fullpath}\n"
            ffmpeg -i "$mp3_fullpath" -vn -ar 44100 -map_channel 0.0.0 "$mp3left_fullpath" -map_channel 0.0.1 "$mp3right_fullpath"
            printf "\n\n******************************************************************\n"
        else
            printf "\n"$mp3left_fullpath" exists. Skipping split.\n"
        fi

        # Confirm files exist and are at least 1kb before moving the stereo file which will not be converted
        if (( $(wc -c < ${mp3left_fullpath}) > 1000 )) && (( $(wc -c < ${mp3right_fullpath}) > 1000 )); then
            printf "\n\nStereo file successfully split. Moving original out of the way. \n"
            mkdir -p "$parentdir"/converted_stereo && mv "$mp3_fullpath" "$parentdir"/converted_stereo
        else
            printf "\nSplit failed - deleting corrupt stereo files.\n"
            rm "$mp3left_fullpath" && rm "$mp3right_fullpath"
        fi

        #********************************************************
        #******************** TRANSCRIPTION *********************
        #********************************************************
        # Transcribe both files after split
        output_json_left=$(echo "${mp3left_fullpath}" | cut -d'.' -f 1).json    # Chop everything at the '.' and add new extension
        output_json_right=$(echo "${mp3right_fullpath}" | cut -d'.' -f 1).json    # Chop everything at the '.' and add new extension

        call_whisper $mp3left_fullpath $output_json_left
        call_whisper $mp3right_fullpath $output_json_right
        printf "\n\n***************** Completed transcription on mono file. \n Saved it to ${output_json}\n\n"
    
    elif [[ "$isMono" == 'true' ]]; then
        #************* TRANSCRIPTION ******************
        call_whisper $mp3_fullpath $output_json
        printf "\n\nCompleted transcription on mono file. \n Saved it to ${output_json}\n\n"
    elif [[ "$isMono" == 'false' ]]; then
        printf "\nFile was not transcribed because it is in stereo but failed splitting process.\n"
        printf "\n****************** \nCould not determine if file is mono or stereo\n"
    fi    
done
popd