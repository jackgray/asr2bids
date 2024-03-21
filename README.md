
# Transcription ETL -- Audio Transcribing, Header Generation, & File renaming

This repository contains tools to transcribe audio speech data, label files and create header sidecar files from the transcriptions and parsing rules


## Transcribe n seconds of audio files
`transcribe_directory.sh`

This script facilitates audio transcription using the Whisper service.

### Usage

./transcribe_directory.sh <parent_directory> <ASR_model> <clip_duration>

- <parent_directory>: Path to the directory containing audio files to transcribe.
- <ASR_model>: The ASR model to use for transcription (tiny, large) see Whisper Web Service documentation for up to date list of available models
- <clip_duration> (Optional): Duration of the audio clip to transcribe. If not provided, the entire audio file is transcribed.

Example: `bash transcribe.sh /path/to/audio_files large 00:00:30`


### Requirements

- ffmpeg: Required for audio processing.
- Docker to run Whisper Webservice endpoint; this script will attempt to start the docker service if it is not running.
- curl: Required for making HTTP requests to Whisper web service
- ensure the port mapped in the docker container matches the port defined in the Whisper endpoint

Remember to provide execute permission to the script before running:

`chmod +x transcribe.sh`


## Create Headers / Rename Files

`make_headers.py`

1. **Labeling:** The Python script labels the transcribed audio files based on their content and formats the header data into a standardized format.

2. **Usage:**

`docker run --rm -d -v ./config:/label_audio.py <transcript_directory> <config.json>`


3. **Parameters:**
- `<transcript_directory>`: The directory containing the transcribed JSON files.
- `<config.json>`: JSON file containing models and configuration settings for parsing the audio content.

4. **Functionality:**
- The script reads the transcribed JSON files from the specified directory.
- It extracts header information such as project, subject, task name, acquisition, etc., from the transcriptions.
- The header data is formatted into a standardized format compatible with the Brain Imaging Data Structure (BIDS) specification.
- It generates labeled JSON files with the formatted header data.

### Workflow

1. **Transcription:**
- Run the shell script (`transcribe_directory.sh`) on a directory of audio files to generate transcribed JSON files.
- Specify the parent directory, ASR model, and optionally, the clip duration.

2. **Labeling:**
- Execute the Python script (`make_headers.py`) with the path to the directory containing the transcribed JSON files and the models configuration file as input arguments.
- The Python script parses the transcribed data, extracts relevant header information, and formats it into BIDS-compatible JSON files.

3. **Integration:**
- Together, the shell script and Python script automate the process of transcribing and labeling audio files, making it easier to manage and analyze large volumes of audio data.
