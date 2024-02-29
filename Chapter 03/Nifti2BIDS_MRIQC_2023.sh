#!/bin/sh
#$ -cwd
#$ -j y
#$ -S /bin/sh
#$ -V

START_TIME=$SECONDS
### Filename: Nifti2BIDS_MRIQC_2023.sh
### Organizes nifti files into BIDS compliant data structure and run MRIQC
### Author: Hsiang Yeh
### email: shawn.j.yeh@gmail.com

# Files required for this step:  
#   Converted files in nifti format, including anatomical and bold sequences. 

### Data information:  These fields are the names of the nifti files.
# SUBJECTS contain the subjects
# SPGR is the high resolution structral scan
# BOLDFILES contains the BOLD files

#SUBJECTS=('S100' 'S101' 'S102' 'S103' 'S104' 'S105' 'S106' 'S107' 'S108' 'S109')
SUBJECTS=('S100' 'S101')

### Sets path to FSL on either cluster or local, comment/uncomment each line as needed.
# *** Local: /usr/share/fsl *** Cluster: /u/home9/FMRI/apps/fsl/current
if [ -z "$FSLDIR" ]; then
  FSL_PATH=/home/syeh/tools/fsl
 else
  FSL_PATH=$FSLDIR
fi
#FSL_PATH=/usr/local/fsl
#FSL_PATH=/u/home9/FMRI/apps/fsl/current


### Sets path to where the fMRI data are stored, expected directory structure is:
# DOC_PATH --- Sub1
#          |-- Sub2
#          |-- Sub3 --- nifti                <-- where data will be loaded from, DATA_PATH
#          |        *-- Sub3-1-nuisance.feat <-- where feat results will be created, RESULT_PATH
#          *-- scripts                       <-- where the script and template files are located
# *** Local: ~/Documents/fMRI *** Cluster: ~/data/fMRI

DOC_PATH=/home/syeh/Documents/fMRI
#DOC_PATH=~/data/fMRI

MRIQC_PATH=${DOC_PATH}/BIDS_files_2023

### BIDS directory structure will be created under $MRIQC_PATH as:
# MRIQC_PATH --- sub-S001
#            |-- sub-S002
#            \-- sub-S003 --- anat --- sub-S003_T1w.nii.gz
#                         |        \-- sub-S003_T1w.json
#                         \-- func --- sub-S003_task-rest_run-1_bold.nii.gz
#                                  \-- sub-S003_task-rest_run-1_bold.json

MRIQC_RPRT=${DOC_PATH}/mriqc_report_2023
if [ ! -d ${MRIQC_PATH} ]; then mkdir ${MRIQC_PATH};fi
if [ ! -d ${MRIQC_RPRT} ]; then mkdir ${MRIQC_RPRT};fi
if [ ! -e ${MRIQC_PATH}/dataset_description.json ]; then echo -e '{\n\t"Name": "2023 fMRI data",\n\t"BIDSVersion": "1.7.0",\n\t"Authors": ["Hsiang J. Yeh",""]\n}' > ${MRIQC_PATH}/dataset_description.json;fi

cd ${DOC_PATH}
#SUBS=`"ls" -d [0-9]*`

for SUB in ${SUBJECTS[@]}; do
  ## Go to working directory and run script there
  DATA_PATH=${DOC_PATH}/${SUB}/nifti
  
  cd ${DATA_PATH}
  echo "Working on $SUB..."
  SPGR=`"ls" *_Crop_1.nii.gz`
  BOLDFILES=(`"ls" *BOLD_*.nii.gz`)
#  DWIFILES=(`"ls" *.bval`)
#  CT=`"ls" *Brain*ab_*.nii.gz`
  if [ ! -d ${MRIQC_PATH}/sub-${SUB} ]; then
    echo "Copying data to MRIQC folder..."
    mkdir -p ${MRIQC_PATH}/sub-${SUB}
    mkdir ${MRIQC_PATH}/sub-${SUB}/anat
    mkdir ${MRIQC_PATH}/sub-${SUB}/func
#    mkdir ${MRIQC_PATH}/sub-${SUB}/dwi
#    mkdir ${MRIQC_PATH}/sub-${SUB}/ct
    cp ${DATA_PATH}/${SPGR} ${MRIQC_PATH}/sub-${SUB}/anat/sub-${SUB}_T1w.nii.gz
    cp ${DATA_PATH}/${SPGR%_Crop_1.nii.gz}.json ${MRIQC_PATH}/sub-${SUB}/anat/sub-${SUB}_T1w.json
#    cp ${DATA_PATH}/${CT} ${MRIQC_PATH}/sub-${SUB}/ct/sub-${SUB}_ct.nii.gz
#    cp ${DATA_PATH}/${CT%.nii.gz}.json ${MRIQC_PATH}/sub-${SUB}/ct/sub-${SUB}_ct.json
  fi

  # Loop through bold files
  for ((i=1; i <= ${#BOLDFILES[@]}; i++)); do
    BOLDNUM=${i}
    if [ ! -e ${MRIQC_PATH}/sub-${SUB}/func/sub-${SUB}_task-rest_run-${i}_bold.nii.gz ]; then
      echo "Copying BOLD $i to MRIQC folder for SUB $SUB..."
      cp ${DATA_PATH}/${BOLDFILES[$[$i-1]]} ${MRIQC_PATH}/sub-${SUB}/func/sub-${SUB}_task-rest_run-${i}_bold.nii.gz
      sed -i ':a;N;$!ba;s#{\n\t"Modality": "MR",#{\n\t"TaskName": "rest",\n\t"Modality": "MR",#' ${DATA_PATH}/${BOLDFILES[$[$i-1]]%.nii.gz}.json
      cp ${DATA_PATH}/${BOLDFILES[$[$i-1]]%.nii.gz}.json ${MRIQC_PATH}/sub-${SUB}/func/sub-${SUB}_task-rest_run-${i}_bold.json
    fi
    
  done
  
  # Loop through dwi files
#  for ((i=1; i <= ${#DWIFILES[@]}; i++)); do
#    if [ ! -e ${MRIQC_PATH}/sub-${SUB}/dwi/sub-${SUB}_run-${i}_dwi.nii.gz ]; then
#      echo "Copying DWI $i to MRIQC folder..."
#      cp ${DATA_PATH}/${DWIFILES[$[$i-1]]} ${MRIQC_PATH}/sub-${SUB}/dwi/sub-${SUB}_run-${i}_dwi.bval
#      cp ${DATA_PATH}/${DWIFILES[$[$i-1]]%.bval}.bvec ${MRIQC_PATH}/sub-${SUB}/dwi/sub-${SUB}_run-${i}_dwi.bvec
#      cp ${DATA_PATH}/${DWIFILES[$[$i-1]]%.bval}.nii.gz ${MRIQC_PATH}/sub-${SUB}/dwi/sub-${SUB}_run-${i}_dwi.nii.gz
#      cp ${DATA_PATH}/${DWIFILES[$[$i-1]]%.bval}.json ${MRIQC_PATH}/sub-${SUB}/dwi/sub-${SUB}_run-${i}_dwi.json
#    fi
#  
#  done

  #read -p "Press enter to continue.."

done

cd ${DOC_PATH}
if [ ! -d ${MRIQC_RPRT}/logs ]; then
  read -p "Press enter to run MRIQC on copied files..."
  docker run -it --rm -v ${MRIQC_PATH}:/data:ro -v ${MRIQC_RPRT}:/out nipreps/mriqc:latest /data /out participant --no-sub
  docker run -it --rm -v ${MRIQC_PATH}:/data:ro -v ${MRIQC_RPRT}:/out nipreps/mriqc:latest /data /out group --no-sub
fi
###END of Script
END_TIME=$SECONDS
DIFF=$[${END_TIME}-${START_TIME}]
echo "Time taken: $[$DIFF / 3600 ] hours $[($DIFF % 3600) / 60] minutes $[$DIFF % 60] seconds"

