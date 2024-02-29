#!/bin/sh

START_TIME=$SECONDS
### Filename: pet2bids_appian.sh
### Convert PET data from DICOM to BIDS compliant nifti, then run APPIAN on it
### Author: Hsiang Yeh
### email: shawn.j.yeh@gmail.com

# Files required for this step:  
#   DICOM files of PET sequence
#   Already converted NIfTI file of MRI T1 for coregistration. 

### Data information:  These fields are the names of the subjects.
# SUBJECTS contain the subjects
# SPGR is the T1 anatomical image

#SUBJECTS=('S100' 'S101' 'S102' 'S103' 'S104' 'S105' 'S106' 'S107' 'S108' 'S109')
SUBJECTS=('S002' 'S003')

### BIDS directory structure will be created under $BIDS_PATH as:
# BIDS_PATH --- sub-S001
#            |-- sub-S002
#            \-- sub-S003 --- anat --- sub-S003_T1w.nii.gz
#                         |        \-- sub-S003_T1w.json
#                         \-- pet  --- sub-S003_run-1_pet.nii.gz
#                                  \-- sub-S003_run-1_pet.json


DOC_PATH=/home/syeh/Documents/PET
#DOC_PATH=~/data/fMRI

BIDS_PATH=${DOC_PATH}/BIDS_files_2023
PET_DICOM_PATH=${DOC_PATH}/DICOM
APPIAN_RPRT=${DOC_PATH}/appian_report_2023
if [ ! -d ${BIDS_PATH} ]; then mkdir ${BIDS_PATH};fi
if [ ! -d ${APPIAN_RPRT} ]; then mkdir ${APPIAN_RPRT};fi
if [ ! -e ${BIDS_PATH}/dataset_description.json ]; then echo -e '{\n\t"Name": "2023 PET data",\n\t"BIDSVersion": "1.8.0",\n\t"Authors": ["Hsiang J. Yeh",""]\n}' > ${BIDS_PATH}/dataset_description.json;fi

cd ${DOC_PATH}

for SUB in ${SUBJECTS[@]}; do
  ## Go to working directory and run script there
  DATA_PATH=${DOC_PATH}/${SUB}/nifti
  
  cd ${DATA_PATH}
  echo "Working on $SUB..."
  SPGR=`"ls" *_Crop_1.nii.gz`
  if [ ! -d ${BIDS_PATH}/sub-${SUB} ]; then
    echo "Copying MRI data to BIDS folder..."
    mkdir -p ${BIDS_PATH}/sub-${SUB}
    mkdir ${BIDS_PATH}/sub-${SUB}/anat
    cp ${DATA_PATH}/${SPGR} ${BIDS_PATH}/sub-${SUB}/anat/sub-${SUB}_T1w.nii.gz
    cp ${DATA_PATH}/${SPGR%_Crop_1.nii.gz}.json ${BIDS_PATH}/sub-${SUB}/anat/sub-${SUB}_T1w.json
  fi

  ## Run dcm2niix4pet using subject specific metadata file if found
  if [ -e ${PET_DICOM_PATH}/${SUB}/subject_metadata.xlsx ]; then
    dcm2niix4pet ${PET_DICOM_PATH}/${SUB}/ -d ${BIDS_PATH}/sub-${SUB}/pet -m ${PET_DICOM_PATH}/${SUB}/subject_metadata.xlsx
  else
    dcm2niix4pet ${PET_DICOM_PATH}/${SUB}/ -d ${BIDS_PATH}/sub-${SUB}/pet -m ${PET_DICOM_PATH}/scanner_metadata.xlsx
  fi

done

cd ${DOC_PATH}
if [ ! -e ${APPIAN_RPRT}/input_file_report.csv ]; then
  read -p "Press enter to run APPIAN on copied files..."
  docker run --rm -it -v ${BIDS_PATH}:/data:ro -v ${APPIAN_RPRT}:/out tffunck/appian:latest bash -c "python3 /opt/APPIAN/Launcher.py -s /data -t /out"
fi
###END of Script
END_TIME=$SECONDS
DIFF=$[${END_TIME}-${START_TIME}]
echo "Time taken: $[$DIFF / 3600 ] hours $[($DIFF % 3600) / 60] minutes $[$DIFF % 60] seconds"

