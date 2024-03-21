'''
Label audio files from spoken information inside them

1. Use bash script on an input folder of audio files to generate transcript.json files
2. Run this script with the path to a folder with transcript.json files in it and path to models.json file as input arguments

4. Generate file name in bids format
5. Generate json file of same format containing bids formatted header data
6. Rename the file (file is not copied--make sure to do this beforehand for testing)

'''

import json
from glob import glob
from sys import argv

inputdir = f"{argv[1]}/*.json"
models = argv[2]
interviewers = json.load(open(models, 'r')) # Load models of all known interviewers

# taking audio from raw_audio, converting it to mp3, and moving it to converted_audio
# inputdir = '/input/*.json'  # directory that contains the raw transcribed files
transcript_files = glob(inputdir)
print(f"\nRenaming these files based on transcript contents: \n{transcript_files}")

# Define parse keywords (normalize everything to lowercase)
subj_delims = ['participant', 'subject', 'ID']
    
error_count = 0
def matchInterviewer(lst1, lst2):
    return set(lst1).intersection(lst2)

    
def parseHeader(transcript, interviewers):
    error_count = 0
    proj, subj, taskname, acq, session = 'NA', 'NA', 'NA', 'NA', 'NA'
    
    header_words = [word.strip('.,') for word in transcript.split()]
    # print(f"\nAnalyzing raw words list: \n{header_words}")
    interviewer_name = ''.join(set(header_words).intersection(interviewers))    # Finds if string exists in both lists; ''.join() converts set object to string
    if len(interviewer_name) > 1:
        print(f"\nMatched interviewer name in transcript with name in models.json: {interviewer_name}")
    else:
        interviewer_name = 'NA'
    # NOTE: if subj ID is less than 5 int characters and/or does not begin with 'S', use the current index position to append i+1 and i-1 (chunks before and after) until conditions are met
    
    # GET PROJECT
    projects = ['more', 'sex differences', 'ERP']
    try:
        proj = ''.join(set(header_words).intersection(projects))    # Finds if string exists in both lists; ''.join() converts set object to string
    except:
        proj = 'NA'
    
    # GET SUBJECT
    try:
        preword = interviewers[interviewer_name]['subj_preword']
        print(preword)
        subj = transcript.split(preword)[-1].split()[0].replace('-','').replace('.','')
        print(subj)
    except:
        
        subj_index = interviewers[interviewer_name]['subj_index']
        try:
            
            # if subj == 'ID':
            #     subj = transcript.split('participant')[1]
            print("Found subject by 'participant' flag: ", subj)
        except:
            subj = header_words[subj_index].replace('-','').strip('.')  # Grabs the index position of transcript as defined in the model for the matched interviewer
        # glue parts together until subj ID is proper length
        
            
        
        print(f"\nPulled subject ID (check if this right?): {subj}")
    
        # try:
        #     print("trying something else")
        #     for word in header_words:
        #         if word.lower() in interviewers[interviewer_name]['subj_preword']:
        #             subj = header_words.split(word)[1]
        #             print("\n\n\n\n\n\n\n\n\nGot subject from keyword delim: ", subj)

        if len(subj) < 3 and subj.startswith('S'):
            for word in header_words:
                if word.startswith('S2') or word.startswith('S1'):
                    subj = word
                    print(f"subj: {subj}")
            while len(subj) < 5:
                subj_index += 1
                nextpart = header_words[subj_index]  # Grabs the index position of transcript as defined in the model for the matched interviewer
                print(f"Subject: {subj}")
                print(f"Now we add: {nextpart}")
                subj = subj.replace('-','').replace('us','S').replace('to','2') + nextpart.replace('-','').replace('.','')
                print(f"Which should give us: {subj}")   
            # if len(subj) > 5:
            #     subj = 'S' + subj.split('S')[-1]
            #     print('Tried to fix incomplete subject ID --> ', subj)
        else:
            proj = 'erp'       
                    
                        # subj = word.intersection(subj)
        
            # exit()
    
    # TASK NAME 
    tasks = ['cvlt', 'fluency']
    try:
        taskname = ''.join(set(header_words).intersection(tasks))    # Finds if string exists in both lists; ''.join() converts set object to string
        print("\nMatched taskname in provided list: ", taskname)
        if len(taskname) < 1:
            taskname = 'NA'
    except:
        try:
            taskname = header_words[interviewers[interviewer_name]['taskname_index']]  # Grabs the index position of transcript as defined in the model for the matched interviewer
            print(f"\nPulled taskname (is this right?): {taskname}")
        except Exception as e:
            print(f"\nError getting the name of the task: {e}")
            # exit()
            try:
                if 'free' in transcript.lower() and 'talk' in transcript.lower():
                    taskname = 'freetalk'
            except:
                print("Still couldn't find task name")
                error_count+=1
    # ACQ
    try:
        # First try to grab part right after task name
        acq_chunk = transcript.split(taskname)[1].split()[:5]
        acq = "".join(acq_chunk[0:2]).strip().lower().replace('one','1').replace('two','2').strip('.')
        # session = header_words[interviewers[interviewer_name]['session_index']]  # Grabs the index position of transcript as defined in the model for the matched interviewer
    except Exception as e:
        print(f"\nError getting the task version : {e}")
        # exit
    
    # keywords
    keywords = ['negative', 'memory', 'remember', 'recall', 'EEG', 'consequences', \
        'positive', 'ERP', 'quitting', 'clean', 'stress', 'craving', 'group', 'second', \
            'part', 'mindful', 'reappraisal', 'coping', 'cocaine', 'heroin', '3-month' 'followup', \
                'MRI', 'movie', 'detail', 'words', 'alphabet', 'read', 'list', 'words', 'alternate', 'CVLT', 'alt' ]
    # DATE   
    try:
        unfmt_date = file.split('_')[0].split('/')[-1]
        isodate = '20' + unfmt_date
        if isodate.startswith('202'):
            fmt_date = "-".join([isodate[4:6], isodate[-2:], isodate[0:4]])
        else:
            print("Trying to parse date from transcript")
            unfmt_date = transcript.split('Today is')[-1].split('.')[0]
            fmt_date = " ".join(unfmt_date.split()[-3:])
            # fmt_date = 'NA'
    except:
        print("No date found, but we can probably get it from file created sys info or file name..")
    
    tags = ','.join(set(header_words).intersection(keywords)).split(',')
    print(tags)
    header_json = dict({
        "project": proj,
        "subject": subj,
        "taskname": taskname,
        "acquisition": acq,
        "session": session,
        "date": fmt_date,
        "interviewer_name": interviewer_name,
        "keywords": tags,
        "text": transcript
    })

    return header_json

    # def makeHeaderfile(raw_hdr_txt):
    #     sentences = raw_hdr_txt.split('.')
    #     words = raw_hdr_txt.split(' ')
    
    #     formatted_header = dict(
    #     {
    #         "sentences": {"a sentence": {"words": ["their", "words"]}},
    #         "words": raw_hdr_txt.split(' '),       
    #     })
    #     count=0
    #     for sentence in sentences:
    #         count+=1
    #         words = sentence.split(' ')
    #         formatted_header["sentences"][sentence] = words
        
    #     print(formatted_header)
        
    #     # Get name
    #     interviewer_name = formatted_header.items()
            


# Each researcher has their own format, so we will first find the researcher
# name to determine which parsing model to try     
# Make parse models for each interviewer based on their style (NOTE: pull these into external mountable config files)

# Sort input files
for file in transcript_files:
    print(f"\nParsing file: {file}...")
    filename = "_".join(file.split('/')[1].split('.')[0].split('_')[0:2])
    try:
        transcript = json.load(open(file, 'r'))['text']    # We only need to grab the first chunk to get header info
        print("Analyzing beginning of transcript: ", transcript)
    except: continue
    # makeHeaderfile(transcript)
    try: 
        header_json = parseHeader(transcript, interviewers)
        print(json.dumps(header_json, indent=4))
        
        outfile = f'sub-{header_json["subject"]}{header_json['project']}_ses-{header_json["session"]}_task-{header_json["taskname"]}_acq-{header_json["acquisition"]}_audio.json' #+ file.split('_')[0].split('/')[1] + ".json"
        print(outfile)
        json.dump(header_json, open(outfile, 'w'), indent = 6)  # Write to file
        
    except Exception as e:
        print(f"\n\nFailed to parse the raw header info:\nError output: {e}\n\ninput text: {transcript}")
    

    # Do the thing
    if not dryrun:
        with open(globpath, 'rb') as audio_file:

            payload = json.loads(
                json.dumps(
                    model.transcribe(
                    audio_file, indent=2)))
            print("payload: ", payload)

    # stores transcribed text

        try:
            results = payload.get('results').pop().get('alternatives').pop().get('transcript') + str[:]
        except Exception as e:
            print(f'{e}')
        
    print(f'\nResults:\n{results}')
print("Number of errors: ", error_count)