#!/bin/sh
#$ -cwd
#$ -j y
#$ -S /bin/sh
#$ -V

START_TIME=$SECONDS
### Filename: Copy_dcm2niix_2022.sh
### Make a copy of DICOM files, then convert them to nifti files
### Author: Hsiang Yeh
### email: shawn.j.yeh@gmail.com

### Files required for this step:
#   DICOM files

### Data information:
# SUBS_DCM contains the DICOM folders to be converted
# SUB is the current subject ID

### Set path to FSL on either cluster or local, comment/uncomment each line as needed.
# *** local: /usr/share/fsl *** cluster: /u/home9/FMRI/apps/fsl/current

FSL_PATH=/usr/share/fsl
#FSL_PATH=/u/home9/FMRI/apps/fsl/current


### Set working directory; expected directory structure is:
# DOC_PATH --- Sub1
#          |-- Sub2
#          |-- Sub3 --- nifti                <-- where data will be loaded from, DATA_PATH
#          |        *-- Sub3-1-nuisance.feat <-- where feat results will be created, RESULT_PATH
#          *-- scripts                       <-- where the script and template files are located
# *** Local: ~/Documents/fMRI *** Cluster: ~/data/fMRI

DOC_PATH=~/Documents/fMRI
#DOC_PATH=~/data/fMRI-EEG

# DICOM_PATH is the working path to which the DICOM files will be placed
DICOM_PATH=${DOC_PATH}/DICOM

# ORIG_DCM is the location of original DICOM files
ORIG_DCM=/media/DICOM1

cd "$ORIG_DCM"
SUBS_DCM=(`"ls" -d ???_*`)
for i in ${SUBS_DCM[@]}; do
  SUB=${i%%_*}
  if [ ! -d ${DICOM_PATH}/${SUB} ]; then
    echo "Copying Subject $SUB from $ORIG_DCM to $DICOM_PATH/$SUB..."
    mkdir -p ${DICOM_PATH}/${SUB}
    cp -r "$ORIG_DCM"/${SUB}_* ${DICOM_PATH}/${SUB}
  fi
  #read -p "Press any key to continue..."

  DATA_PATH=${DOC_PATH}/${SUB}/nifti
  if [ ! -d ${DATA_PATH} ]; then
    echo "Converting DICOM to Nifti for $SUB..."
    mkdir -p ${DATA_PATH}
    dcm2niix -o ${DATA_PATH} -i y -z o -x y ${DICOM_PATH}/${SUB}
  fi
  #read -p "Press any key to continue..."

done

###END of Script
END_TIME=$SECONDS
DIFF=$[${END_TIME}-${START_TIME}]
echo "Time taken: $[$DIFF / 3600 ] hours $[($DIFF % 3600) / 60] minutes $[$DIFF % 60] seconds"
