Label audio files from spoken information inside them

1. Use a bash script on an input folder of audio files to generate transcript.json files
2. Run the Python script with the path to a folder with transcript.json files and the path to models.json file as input arguments
3. The Python script will:
   - Generate file names in BIDS format
   - Generate JSON files containing BIDS-formatted header data
   - Rename the files (files are not copied, make sure to do this beforehand for testing)

---

## Audio Labeling Tool

This tool assists in labeling audio files based on the spoken information contained within them. It includes both a shell script and a Python script to process the audio files and generate labeled JSON files containing header data.



# Whisper Audio Transcription Script

This script facilitates audio transcription using the Whisper service.

## Usage

./transcribe_directory.sh <parent_directory> <ASR_model> <clip_duration>

- <parent_directory>: Path to the directory containing audio files to transcribe.
- <ASR_model>: The ASR model to use for transcription.
- <clip_duration> (Optional): Duration of the audio clip to transcribe. If not provided, the entire audio file is transcribed.

## Requirements

- ffmpeg: Required for audio processing.
- curl: Required for making HTTP requests.

## Caveats and Clarifications

- Ensure that the ASR model specified is compatible with the Whisper service.
- The script assumes that audio files are in a compatible format for transcription.
- If <clip_duration> is not provided, the entire audio file is transcribed.
- Make sure to provide the correct paths to the audio files and the Whisper service endpoint.

## Gotchas

- If audio files are too large, transcription may take a long time or fail.
- Ensure that the Whisper service is running and accessible from the provided endpoint.
- Check the ASR model compatibility with the Whisper service.

Replace <parent_directory>, <ASR_model>, and <clip_duration> with appropriate values according to your use case.

./transcribe.sh /path/to/audio_files model_name 00:05:00

This command transcribes audio files in /path/to/audio_files directory using the specified ASR model (model_name) with a clip duration of 5 minutes.

./transcribe.sh /path/to/audio_files model_name

This command transcribes the entire audio files in /path/to/audio_files directory using the specified ASR model (model_name).

Remember to provide execute permission to the script before running:

chmod +x transcribe.sh


### Python Script (`label_audio.py`)

1. **Labeling:** The Python script labels the transcribed audio files based on their content and formats the header data into a standardized format.

2. **Usage:**

`python label_audio.py <transcript_directory> <config.json>`


3. **Parameters:**
- `<transcript_directory>`: The directory containing the transcribed JSON files.
- `<models.json>`: JSON file containing models and configuration settings for parsing the audio content.

4. **Functionality:**
- The script reads the transcribed JSON files from the specified directory.
- It extracts header information such as project, subject, task name, acquisition, etc., from the transcriptions.
- The header data is formatted into a standardized format compatible with the Brain Imaging Data Structure (BIDS) specification.
- It generates labeled JSON files with the formatted header data.

### Workflow

1. **Transcription:**
- Run the shell script (`transcribe_audio.sh`) on a directory of audio files to generate transcribed JSON files.
- Specify the parent directory, ASR model, and optionally, the clip duration.

2. **Labeling:**
- Execute the Python script (`label_audio.py`) with the path to the directory containing the transcribed JSON files and the models configuration file as input arguments.
- The Python script parses the transcribed data, extracts relevant header information, and formats it into BIDS-compatible JSON files.

3. **Integration:**
- Together, the shell script and Python script automate the process of transcribing and labeling audio files, making it easier to manage and analyze large volumes of audio data.
