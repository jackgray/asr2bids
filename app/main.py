'''
Label audio files from spoken information inside them

1. Scan input folder for audio files
2. Loop through all files in input directory
3. Filter filetypes (mp3, wav, etc), chop first 10 seconds, save to temp file
2. Transcribe
3. Parse header information
4. Generate file name in bids format
5. Generate json file of same format containing bids formatted header data
6. Rename the file (file is not copied--make sure to do this beforehand for testing)

'''

import json
# import whisper
# from pydub import AudioSegment
from glob import glob

# Load which whisper model to use: tiny, base, large, etc (larger is more accurate and takes more space)
# model = whisper.load_model("base")

# taking audio from raw_audio, converting it to mp3, and moving it to converted_audio
inputdir = '/input/*.json'  # directory that contains the raw transcribed files
tmpfile = '/tmp/tmpfile'

audio_files = glob(inputdir)
print(audio_files)
# Define parse keywords (normalize everything to lowercase)
subj_keywords = ['participant', 'subject', 'id', 's']

# Make parse models for each interviewer based on their style (NOTE: pull these into external mountable config files)
interviewer = \
    dict({
        'lily': {
            'subj_index': 9
            }, 
        'gabby': {
            'subj_index': 6
            }, 
        'natalie': {
            'subj_index': 5
            },
        'pedro': {
            'subj_index': 4
        },
        'pasia': {
            'subj_index': 6
        }
    })

def makeClip(file):
    print(f"\nChopping the beginning of this file: {file} ...")
    ext = file.split('.')[-1].lower()   # normalize caps and lowercase extensions
    if ext == 'mp3':
        audiofile = AudioSegment.from_mp3(file)
    elif ext == 'wav':
        audiofile = AudioSegment.from_wav(file)
    else:
        audiofile = AudioSegment.from_file(file, ext) 
        
    header_clip = audiofile[:30000].export(tmpfile)  
    print("temp file was successfully created")
# Function for individual file (to be looped below)
def changeName(tmpfile=tmpfile):
    print(f"\nLoading generated audio file")
    try:
        loaded_file = whisper.load_audio(tmpfile)
    except:
        print(f"\nWhisper could not load the audio file.\n")
    result = model.transcribe(tmpfile)
    transcription = result["text"]
    print(f"\n\n\n-------------------------------------- \
        \n RAW TRANSCRIPTION\n\n{transcription} \
            \n\n--------------------------------------")
    
    # We must try multiple methods to account for transcription inaccuracy
    # (1) Spaces, (2) keywords
    
    # Each researcher has their own format, so we will first find the researcher
    # name to determine which parsing model to try
    def getInterviewerName():
        header_words = transcription.split()
        
    
    # Method 1: By spaces
    def parseSpaces():
        # NOTE: if subj ID is less than 5 int characters and/or does not begin with 'S', use the current index position to append i+1 and i-1 (chunks before and after) until conditions are met
        header_words = transcription.split()
        index = 0
        for word in header_words.lower():
            for keyword in subj_keywords:
                if word.startswith(keyword) or word == keyword:
                    subj = word
                    if subj.length() < 6:
                        subj.append(word)
                        print(f"Subject: {subj}")
                        # continue loop but add to subj ID
                        continue
            if word.lower() == 'fluency':
                taskname = 'fluency'
            elif word.lower() == 'natalie':
                interviewer = 'Natalie'
            index += 1
    
    def keywords():
        for keyword in subj_keywords:
            try:
                header_words = result["text"].split(keyword)
                for word in header_words:
                    print(word)
            except:
                
                pass    
    try: parseSpaces()
    except: pass
    try: keywords()
    except: pass
    # filename = "_".join(f'sub-{subj}')
    # print(f"\nSubject ID: {subj} \nTask: {taskname} \nInterviewer: {interviewer}")


# Sort input files
for file in audio_files:
    print(f"\nScanning file: {file}...")
    try: makeClip(file)
    except Exception as e:
        print(f"\nPyDub couldn't make the clip: {e}")
        continue    # move to next file
    try:
        changeName()
    except Exception as e:
        print(e)
        continue
    
    # Parse header info
    

# Do the thing
#     with open(globpath, 'rb') as audio_file:

#         payload = json.loads(
#             json.dumps(
#                 model.transcribe(
#                    audio_file, indent=2)))
#         print("payload: ", payload)

# # stores transcribed text

#     try:
#         results = payload.get('results').pop().get('alternatives').pop().get('transcript') + str[:]
#     except Exception as e:
#         print(f'{e}')
        
#     print(f'\nResults:\n{results}')
