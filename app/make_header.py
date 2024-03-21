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
import os

parser = argparse.ArgumentParser(description="Label audio files from spoken information inside them")
parser.add_argument("input_directory", metavar="input_directory", type=str, nargs="?", default="input",
                    help="Path to the input directory containing transcript JSON files")
parser.add_argument("config_path", metavar="config_path", type=str, nargs="?", default="/config/config.json",
                    help="Path to the configuration JSON file")

args = parser.parse_args()


def load_config(config_path):
    """Load configuration from JSON file."""
    try:
        with open(config_path, 'r') as config_file:
            return json.load(config_file)
    except FileNotFoundError:
        print(f"Configuration file '{config_path}' not found.")
        return None
    except json.JSONDecodeError:
        print(f"Invalid JSON format in '{config_path}'.")
        return None

def load_input_directory(input_path):
    """Load input directory path."""
    if os.path.isdir(input_path):
        return input_path
    else:
        print(f"Input directory '{input_path}' not found.")
        return None

transcript_files = glob(inputdir)
print(f"\nRenaming these files based on transcript contents: \n{transcript_files}")

# Define parse keywords (normalize everything to lowercase)
subj_delims = ['participant', 'subject', 'ID']
    
error_count = 0

def extract_subject(transcript, interviewers):
    """
        Extract subject ID from the transcript using regular expression .
        
        Each researcher has their own format, so we will first find the researcher name to determine which parsing model to try     
        Edit parse models for each interviewer based on their interview style in config.json
    """

    subj_preword = interviewers.get('subj_preword', None)
    subj_index = interviewers.get('subj_index', None)

    if subj_preword:
        pattern = re.compile(fr"\b{re.escape(subj_preword)}\b\s*([^\s]+)")
        match = pattern.search(transcript)
        if match:
            return match.group(1).replace('-', '').replace('.', '').strip()
    
    elif subj_index is not None:
        words = transcript.split()
        if subj_index < len(words):
            return words[subj_index].replace('-', '').strip('.')
    
    return None
    
    # TASK NAME 
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


def parse_header(transcript, interviewers):
    """Parse header information from the transcript."""

    error_count = 0
    proj, subj, taskname, acq, session = 'NA', 'NA', 'NA', 'NA', 'NA'
    
    header_words = [word.strip('.,') for word in transcript.split()]    # turn transcript to array, removing special characters
    # print(f"\nAnalyzing raw words list: \n{header_words}")
    interviewer_name = ''.join(set(header_words).intersection(interviewers))    # Scan transcript list for interviewer name match in config file
    if len(interviewer_name) > 1:
        print(f"\nMatched interviewer name in transcript with name in models.json: {interviewer_name}")
    else:
        interviewer_name = 'NA'
    # NOTE: if subj ID is less than 5 int characters and/or does not begin with 'S', use the current index position to append i+1 and i-1 (chunks before and after) until conditions are met (sometimes subject IDs are transcribed with - or [[space]] between the numbers)
    
    # GET PROJECT
    try:
        proj = ''.join(set(header_words).intersection(projects))    # Finds if string exists in both lists; ''.join() converts set object to string
    except:
        proj = 'NA'
    
    subj = extract_subject()

    # ACQ
    try:
        # First try to grab part right after task name
        acq_chunk = transcript.split(taskname)[1].split()[:5]
        acq = "".join(acq_chunk[0:2]).strip().lower().replace('one','1').replace('two','2').strip('.')
        # session = header_words[interviewers[interviewer_name]['session_index']]  # Grabs the index position of transcript as defined in the model for the matched interviewer
    except Exception as e:
        print(f"\nError getting the task version : {e}")
        # exit
    
    # Dates are often not transcribed with proper formatting.
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
    print(f'Collected tags from transcript: {tags}')

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


def main(input_directory, config_path):
    # Load configuration and input directory
    config = load_config(config_path)
    if config is None:
        return

    input_directory = load_input_directory(input_directory)
    if input_directory is None:
        return

    # Extract necessary information from the config
    projects = config.get('projects', [])
    interviewers = config.get('interviewers', {})
    keywords = config.get('keywords', [])

    # Sort input files
    transcript_files = glob(os.path.join(input_directory, '*.json'))

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


if __name__ == "__main__":

    main(args.input_directory, args.config_path)