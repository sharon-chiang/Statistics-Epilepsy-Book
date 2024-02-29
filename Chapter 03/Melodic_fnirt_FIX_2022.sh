#!/bin/sh
#$ -cwd
#$ -j y
#$ -S /bin/sh
#$ -V

START_TIME=$SECONDS
### Filename: Melodic_fnirt_FIX_2022.sh
### Run Melodic with registration, mcflirt, and bet.  Then run FIX automatic noise removal.
### Author: Hsiang Yeh
### email: shawn.j.yeh@gmail.com

# Files required for this step:  
#   Converted files in nifti format, with structural and bold sequences. 

### Data information:  These fields are the names of the nifti files.
# SUBJECTS contain the subject IDs
# 3dspgr.nii.gz is the high resolution structral scan
# IMGNAME is the current BOLD file being worked on

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

DOC_PATH=~/Documents/fMRI
#DOC_PATH=~/data/fMRI

### Path to the design templates
MELODIC_TEMPLATE_PATH=${DOC_PATH}/scripts/Melodic_ICA_reg_mcf_for_FIX_Template.fsf


cd ${DOC_PATH}
#SUBJECTS=(`"ls" -d [0-9]*`)

for ((i=1; i <= ${#SUBJECTS[@]}; i++)); do
  SUB=${SUBJECTS[$[$i-1]]}
  RESULT_PATH=${DOC_PATH}/${SUB}
  DATA_PATH=${RESULT_PATH}/nifti
  cd ${DATA_PATH}

  ## Run N4BiasFieldCorrection on anat
  if [ ! -e N4_3dspgr.nii.gz ]; then
    echo "Brain extracting anatomical images..."
    bet 3dspgr.nii.gz 3dspgr_brain.nii.gz -R -m -n
    N4BiasFieldCorrection -d 3 -i 3dspgr.nii.gz -x 3dspgr_brain_mask.nii.gz -r 1 -o N4_3dspgr.nii.gz
    bet N4_3dspgr.nii.gz 3dspgr_brain.nii.gz -R -m
  fi

  ##Loop over each subject's BOLD files
  j=1
  for IMGNAME in `'ls' BOLD*.nii.gz`; do

    ##Run MELODIC with registration, mcflirt, bet
    cd ${DATA_PATH}
    if [ ! -e ${RESULT_PATH}/$SUB-${j}-mel-reg-mcf.ica ]; then
      IMGNAME=${IMGNAME%.nii.gz}
      NUMVOL=`fslnvols ${DATA_PATH}/${IMGNAME}`
      VOLINFO=(`fslstats ${DATA_PATH}/${IMGNAME} -v`)
      TRINFO=(`fslinfo ${DATA_PATH}/${IMGNAME}|grep pixdim4`)
      MEL_DESIGN=${SUB}-${j}-melodic.fsf

      # regexp note: g and I flags denote (g) apply globally (all match instances) and (I) apply to all letter cases
      sed -e "s#=FSL_PATH#${FSL_PATH}#" -e "s#=RESULT_PATH#${RESULT_PATH}#" -e "s#=DATA_PATH#${DATA_PATH}#" -e "s#=SUB#${SUB}#g" -e "s#=NVOL#${NUMVOL}#" -e "s#=IMGNAME#${IMGNAME}#" -e "s#=SESSNUM#${j}#" -e "s#=NUMTR#${TRINFO[1]}#" -e "s#=TOTALVOX#${VOLINFO[0]}#" $MELODIC_TEMPLATE_PATH > ${DATA_PATH}/$MEL_DESIGN
      echo "***Running MELODIC on Subject $SUB session $j***"
      feat ${DATA_PATH}/${MEL_DESIGN}
    else
      echo "Result exists!  Skipping MELODIC of $SUB session $j"
    fi
    
    if [ ! -f ${RESULT_PATH}/$SUB-${j}-mel-reg-mcf.ica/filtered_func_data_clean.nii.gz ]; then
      echo "Running FIX automatic ICA denoising on $SUB session $j"
      ~/tools/fix/fix ${RESULT_PATH}/${SUB}-${j}-mel-reg-mcf.ica ~/tools/fix/training_files/Standard.RData 15 -m
    else
      echo "Result exists!  Skipping FIX ICA denoising of $SUB session $j"
    fi
    

  #read -p "Press enter to continue.."
  if [ -f ${DATA_PATH}/${MEL_DESIGN} ]; then rm ${DATA_PATH}/${MEL_DESIGN}; fi
  j=$[$j+1]
  done

done
###END of Script
END_TIME=$SECONDS
DIFF=$[${END_TIME}-${START_TIME}]
echo "Time taken: $[$DIFF / 3600 ] hours $[($DIFF % 3600) / 60] minutes $[$DIFF % 60] seconds"

