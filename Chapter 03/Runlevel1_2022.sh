#!/bin/sh
#$ -cwd
#$ -j y
#$ -S /bin/sh
#$ -V

START_TIME=$SECONDS
### Filename: Runlevel1_2022.sh
### Run nuisance level analysis, regressing out motion and other unwanted signals
### Author: Hsiang Yeh
### email: shawn.j.yeh@gmail.com

# Files required for this step:  
# Previously Melodic and FIX analysis resulting in cleaned filtered_func

### Data information:  These fields are the names of the nifti files.
# SUBJECTS contain the subjects

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

### Path to the FEAT design templates
NUI_FEAT_TEMPLATE_PATH=${DOC_PATH}/scripts/fsl600_design_RestingState_nuisance_run_segcsfwm_eigen_motion_outliers_Template.fsf

OUT_SUFFIX=RS-nuisance-SegCSFWM-eigen-motionscrubbed

for ((i=1; i <= ${#SUBJECTS[@]}; i++)); do
  SUB=${SUBJECTS[$[$i-1]]}
  RESULT_PATH=${DOC_PATH}/${SUB}
  cd ${RESULT_PATH}

  ##Loop over each subject's BOLD sessions
  for ICA in `"ls" -d ${SUB}-?-mel-reg-mcf.ica`;do
    ITMP=${ICA#${SUB}-}
    j=${ITMP%-mel-reg-mcf.ica} #find j
    DATA_PATH=${DOC_PATH}/${SUB}/nifti
    MEL_PATH=${DOC_PATH}/${SUB}/${ICA}
    IMGNAME=${MEL_PATH}/filtered_func_data_clean
    NUI_DESIGN=${SUB}-${j}-RS-nuisance_run.fsf
    
    cd ${DATA_PATH}
    ## Generate motion files if not there
    if [ ! -f ${SUB}-${j}-motion6 ]; then
      echo "Generating motion parameter files..."
      extractmotion ${MEL_PATH}/mc/prefiltered_func_data_mcf.par ${SUB}-${j}
    fi

    ##Segment anatomical brain, then threshold result to make into CSF and WM masks
    if [ ! -f ${DATA_PATH}/3dspgr_brain_pveseg.nii.gz ]; then
      echo "Segmenting anatomical image for ${SUB}..."
      fast -t 1 -n 3 -H 0.1 -I 4 -l 20.0 -a ${MEL_PATH}/reg/standard2highres.mat -o ${DATA_PATH}/3dspgr_brain ${DATA_PATH}/3dspgr_brain
      fslmaths 3dspgr_brain_pve_0.nii.gz -ero -thr .9 -bin 3dspgr_CSF_mask
      fslmaths 3dspgr_brain_pve_2.nii.gz -ero -thr .9 -bin 3dspgr_WM_mask
      rm 3dspgr_brain_csf_stdspace.nii.gz
	  rm 3dspgr_brain_gm_stdspace.nii.gz
	  rm 3dspgr_brain_wm_stdspace.nii.gz
	  rm 3dspgr_brain_mixeltype.nii.gz
	  rm 3dspgr_brain_pve_1.nii.gz
	  rm 3dspgr_brain_seg.nii.gz
    fi

    ##Transform CSF and WM mask into session space and extract time series
    if [ ! -f ${DATA_PATH}/CSF_segmask-eig-seed$j.txt ]; then
      echo "Transforming and extracting CSF time series from ${SUB} session ${j}..."
      flirt -in 3dspgr_CSF_mask.nii.gz -ref ${MEL_PATH}/reg/example_func.nii.gz -applyxfm -init ${MEL_PATH}/reg/highres2example_func.mat -out ${SUB}-${j}-CSF_segmask -interp nearestneighbour
      fslmeants -i ${IMGNAME} -m ${DATA_PATH}/${SUB}-${j}-CSF_segmask --eig > ${DATA_PATH}/CSF_segmask-eig-seed$j.txt;
      #cat ${DOC_PATH}/scripts/norm_vec.R | R --slave --args CSF_segmask-seed$j.txt --no-save
      rm ${SUB}-${j}-CSF_segmask.nii.gz
      #rm CSF_segmask-seed$j.txt
    else
      echo "--Skipping CSF Time Series Extraction-- Result exists!"
    fi
    if [ ! -f ${DATA_PATH}/WM_segmask-eig-seed$j.txt ]; then
      echo "Transforming and extracting WM time series from ${SUB} session ${j}..."
      flirt -in 3dspgr_WM_mask.nii.gz -ref ${MEL_PATH}/reg/example_func.nii.gz -applyxfm -init ${MEL_PATH}/reg/highres2example_func.mat -out ${SUB}-${j}-WM_segmask -interp nearestneighbour
      fslmeants -i ${IMGNAME} -m ${DATA_PATH}/${SUB}-${j}-WM_segmask --eig > ${DATA_PATH}/WM_segmask-eig-seed$j.txt;
      #cat ${DOC_PATH}/scripts/norm_vec.R | R --slave --args WM_segmask-seed$j.txt --no-save
      rm ${SUB}-${j}-WM_segmask.nii.gz
      #rm WM_segmask-seed$j.txt
    else
      echo "--Skipping WM Time Series Extraction-- Result exists!"
    fi

	##Generate outlier matrix if doesn't exist
    if [ ! -e ${DATA_PATH}/${SUB}-${j}-outliermat.txt ]; then
      echo "Running fsl_motion_outliers for Subject $SUB session $j***"
      fsl_motion_outliers --nomoco -i ${IMGNAME} -o ${SUB}-${j}-outliermat.txt
    else
      echo "Result exists!  Skipping outlier detection of $SUB session $j"
    fi

    ##Run feat
    cd ${DATA_PATH}
    OUTPUT_DIR=${RESULT_PATH}/$SUB-${j}-${OUT_SUFFIX}.feat
    if [ ! -e ${OUTPUT_DIR} ]; then
      NUMVOL=`fslnvols ${IMGNAME}`
      VOLINFO=(`fslstats ${IMGNAME} -v`)
      TRINFO=(`fslinfo ${IMGNAME}|grep pixdim4`)

      # regexp note: g and I flags denote (g) apply globally (all match instances) and (I) apply to all letter cases
      sed -e "s#=IMGNAME#${IMGNAME}#" -e "s#=OUTPUT_DIR#${OUTPUT_DIR}#" -e "s#=FSL_PATH#${FSL_PATH}#" -e "s#=SUB#${SUB}#" -e "s#=SESSNUM#${j}#" -e "s#=DATA_PATH#${DATA_PATH}#" -e "s#=NVOL#${NUMVOL}#" -e "s#=NUMTR#${TRINFO[1]}#" -e "s#=TOTALVOX#${VOLINFO[0]}#" $NUI_FEAT_TEMPLATE_PATH > ${DATA_PATH}/$NUI_DESIGN
      echo "***Running Nuisance step for Subject $SUB session $j***"
      feat ${DATA_PATH}/${NUI_DESIGN}
    else
      echo "Result exists!  Skipping nuisance FEAT of $SUB session $j"
    fi

  #read -p "Press enter to continue.."
  if [ -f ${DATA_PATH}/${NUI_DESIGN} ]; then rm ${DATA_PATH}/${NUI_DESIGN}; fi
  done

done
###END of Script
END_TIME=$SECONDS
DIFF=$[${END_TIME}-${START_TIME}]
echo "Time taken: $[$DIFF / 3600 ] hours $[($DIFF % 3600) / 60] minutes $[$DIFF % 60] seconds"

