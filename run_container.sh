#!/bin/env bash
source .env
echo $NARCASR_INPUT_DIR
# VERSION="v2.0.7"
VERSION='0.0.1'

#Usage message to display
usage()
{
  echo -en "\nSYNTAX ERROR\n"
  echo -e "usage: $0 [ -d department -p project_id -a arguments -u username_for_xnat]\n"
  echo -e "Where directory is before the projects\n"
  echo -en "[arguments] can be:\n
Individual:
            [pull] - Pull all bids data into appropriate directories
        [pull_all] - Download and sort all available data
              [nm] - Download neuromelanin into /derivatives/neuromelanin
           [split] - Split multivolume data.
          [intend] - Apply intendedFor and taskName
            [auth] - Set up your login credintials
          [custom] - Supply keyword(s) (separate multiples by comma) to -k flag 
                     to pull all series for given exams that match by series description. 
                     Supply optional -x flag with exclude words to filter more.

Combined:
     [pulltosplit] - pull + split
    [pulltointend] - pull + split + intend
   [splittointend] - split + intend
"
}



########################### PARSE ARGUMENTS ############################

# Ensure minimum args are supplied
if [[ $# -lt 3 ]]; then
  usage
  exit 1
fi

# Read command arguments
while [ "$1" != "" ]; do
    case $1 in
        -l )      shift
                  log=$1
                  ;;
        -d )      shift
                  dept=$1
                  ;;
        -p )      shift
                  project_id=$1
                  ;;
        -u )      shift
                  username=$1
                  ;;
        -a )      shift
                  arg=$1
                  ;;
        -e )      shift
                  exam_no=$1
                  ;;
        -k )      shift
                  keywords=$1
                  ;;
        -x )      shift
                  excludes=$1
    esac
    shift
done


############################## CONTAINER SETUP #################################

image_name=jackgray/xnat_sync:${VERSION}

#----------SERVICE NAME---------------
service_name=xnat2bids_setup_`id -un`
#-------------------------------------

# Set defaults if flags are omitted
if [ -z "${dept}" ]; then
  dept=nyspi
  echo "using $dept for department"
fi

# if [ -z "${xnat_url}" ]; then
#   xnat_url=bmeii.mssm.edu/xnat

# Ensure custom arg satisfied by -k flag
if [[ "$arg" == "custom" &&  -z "${keywords}" ]]; then 
  echo -en "\n  You must specify at least one keyword for data pull. 
  You may use -x to create an exclude list: i.e; '-custom -k fgre,struc,t1 -x nm,loc,t2,test,mux.'\n\n"
  exit 1
fi 

# UID and GID
uid=$(id -u)  # UID of person running this script for permission-fixing | could be set with config file
printf "\nUsing UID ${uid}"
groupinfo=$(getent group ${project_id}) # Pull group ID from project_id (working_gid)
printf "\nPulled group ID from project ID ${project_id}: ${groupinfo}"

while IFS=$':' read -r -a tmp ; do
  gid="${tmp[2]}"
  printf "\ngid=${gid}"
done <<< $groupinfo

TOF=$(date +"%Ih%M%p")  # hour-minute time in docker & unix acceptable format | ex: 01h15pm
printf "\nSet container time of flight as ${TOF}"

# service_name=${project_id}_xnatSync_${type}_${username}_${TOF,,}

project_path=${PROJECTS_HOME}/${project_id}


# User Tokens
user_token_file=${PROJECTS_HOME}/.xnatauth/${username}_xnat_login.bin
user_alias_file=${PROJECTS_HOME}/.xnatauth/${username}_alias_token.bin

log_file=${user_folder}/logs/${service_name}.log

working_list_path_doctor=${project_path}/scripts
working_list_path_container=/scripts

# Data Locations
derivatives_path_doctor=${project_path}/derivatives
derivatives_path_container=/derivatives
bidsonly_path_doctor=${derivatives_path_doctor}/bidsonly
bidsonly_path_container=/bidsonly
nm_path_doctor=${derivatives_path_doctor}/neuromelanin
nm_path_container=/neuromelanin
rawdata_path_doctor=${project_path}/rawdata 
rawdata_path_container=/rawdata

# Token Mounts
token_path_doctor=${PROJECTS_HOME}/.xnatauth
token_path_container=/tokens
private_path_doctor=${PROJECTS_HOME}/.xnatauth
private_path_container=/privatekeys
public_path_doctor=${PROJECTS_HOME}/.xnatauth
public_path_container=/publickeys

displayRunMessage(){

  echo -en "\n =================== $service_name is running=========================== \n"
  echo -en "\n      =================== Please wait =========================== \n"

  while [ "$(docker service ps ${service_name} 2> /dev/null | awk '{print $6}' | sed -n '2p')"  != 'Failed' ] \
  && [ "$(docker service ps ${service_name} 2> /dev/null | awk '{print $6}' | sed -n '2p')"  != 'Complete' ] ; do
    echo $(docker service ps ${service_name} 2> /dev/null | awk '{print $6}' | sed -n '2p') >> /dev/null 2>&1 
  done 
}
#- - - - - - - - - - - - - - - - - AUTH - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

# AUTH CONTAINER 
runAuthContainer(){
printf "\n\nCouldn't find token file. Running authentication service."
/usr/bin/docker run \
-it --rm \
--env project_id=${project_id} \
-e department=${dept} \
-e uid=${uid} \
-e gid=${gid} \
-e username=${username} \
-e exam_no=${exam_no} \
-e type=${type} \
-e host=${host} \
-e projects_home=${PROJECTS_HOME} \
-e xnat_url=${xnat_url} \
-e action=${arg} \
--name=${service_name} \
--mount type=bind,source=${working_list_path_doctor},destination=${working_list_path_container} \
--mount type=bind,source=${rawdata_path_doctor},destination=${rawdata_path_container} \
--mount type=bind,source=${bidsonly_path_doctor},destination=${bidsonly_path_container} \
--mount type=bind,source=${token_path_doctor},destination=${token_path_container} \
--mount type=bind,source=${private_path_doctor},destination=${private_path_container} \
--mount type=bind,source=${public_path_doctor},destination=${public_path_container} \
jackgray/xnat_auth:${VERSION}
}
#- - - - - - - - - - - - - - - - PULL - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
