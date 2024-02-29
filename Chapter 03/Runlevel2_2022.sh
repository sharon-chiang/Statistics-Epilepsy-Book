#!/bin/sh
#$ -cwd
#$ -j y
#$ -S /bin/sh
#$ -V

START_TIME=$SECONDS
### Filename: Runlevel2_2022.sh
### Run seed-based analysis based on selected ROI
### Author: Hsiang Yeh
### email: shawn.j.yeh@gmail.com

# Files required for this step:  
# Previously run Melodic w/ registration, FIX, and nuisance analysis

### Data information:
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

### Path to the correlation design template
FEAT_TEMPLATE_PATH=${DOC_PATH}/scripts/fsl600_design_RestingState_correlation_run_Template.fsf

NUI_DIR=RS-nuisance-SegCSFWM-eigen-motionscrubbed.feat
FILEO=res4d
SEEDNAME=GPi

ATLAS_PATH=${DOC_PATH}/atlas
BNAME=('low')
BLSIG=('0.01')
BHSIG=('0.1')

for ((j=0; j <= $[${#BNAME[@]}-1]; j++)); do
 
  for SUB in ${SUBJECTS[@]}; do
   RESULT_PATH=${DOC_PATH}/${SUB}
   DATA_PATH=${RESULT_PATH}/nifti
   cd ${RESULT_PATH}
   
   for NUI in `"ls" -d ${SUB}-?-${NUI_DIR}`;do
    ITMP=${NUI#${SUB}-}
    i=${ITMP%-${NUI_DIR}} #find i
    FILEN=res4d_${BNAME[$j]}
    SEED_FILE=${SEEDNAME}_${BNAME[$j]}-outliers-seed$i.txt
    OUTFILE=${SUB}-$i-correlation_run_${SEEDNAME}.fsf
    OUTPUT_DIR=${SUB}-$i-correlation-${SEEDNAME}_${BNAME[$j]}-outliers.feat
    REG_PATH=${RESULT_PATH}/${SUB}-$i-mel-reg-mcf.ica/reg
    NUI_PATH=${RESULT_PATH}/${SUB}-$i-${NUI_DIR}
 
    echo "Working on $SUB session ${i} frequency band: ${BNAME[$j]}"
 
    cd ${NUI_PATH}/stats
    if [ ! -f scaled_${FILEN}.nii.gz ] && [ ! -d ${DOC_PATH}/${SUB}/${OUTPUT_DIR} ]; then
      TR=(`fslinfo ${FILEO} |grep pixdim4`)
      #echo "TR is: ${TR[1]}"

      ## Bandpass
      LOWF=`echo "scale=3;1/(2*${BLSIG[$j]}*${TR[1]})"|bc -l`
      HIGHF=`echo "scale=3;1/(2*${BHSIG[$j]}*${TR[1]})"|bc -l`
      echo "Applying bandpass filter (${LOWF} - ${HIGHF} sigma) on time series (TR=${TR[1]}) of $SUB..."
      fslmaths ${FILEO} -bptf ${LOWF} ${HIGHF} ${FILEN} -odt float
 
      ## scale time series
      echo "Scaling time series of $SUB..."
      fslmaths ${FILEN} -Tmean -abs -bin mask
      fslmaths ${FILEN} -Tmean mn_${FILEN}_tmp
      fslmaths ${FILEN} -Tstd std_${FILEN}_tmp
      fslmaths ${FILEN} -sub mn_${FILEN}_tmp -div std_${FILEN}_tmp -add 100 -mul mask scaled_${FILEN}
      rm *${FILEN}_tmp*
    else
      echo "--Skipping bandpass and scaling--  Result exists!"
    fi


    ##flirt ROI seed, extract time series, and normalize it
    if [ ! -f ${DATA_PATH}/norm_${SEED_FILE} ]; then
      cd ${REG_PATH}
      if [ ! -f standard2example_func_warp.nii.gz ]; then
        echo "Generating inverse warp for $SUB session $i..."
        invwarp --ref=example_func --out=standard2example_func_warp --warp=example_func2standard_warp
      fi
      echo "Transforming seed and extracting ${SEEDNAME} time series from $SUB session $i..."
      applywarp --ref=example_func --in=${ATLAS_PATH}/${SEEDNAME} --out=${DATA_PATH}/$SUB-$i-seed${SEEDNAME} --warp=standard2example_func_warp --interp=nn
      fslmeants -i ${NUI_PATH}/stats/scaled_${FILEN} -m ${DATA_PATH}/$SUB-$i-seed${SEEDNAME} > ${DATA_PATH}/${SEED_FILE};
      cd ${DATA_PATH}
      conda activate fslR
      cat ${DOC_PATH}/scripts/norm_vec.R | R --slave --args ${SEED_FILE} --no-save
      conda deactivate
      #rm ${SEED_FILE}
    else
      echo "--Skipping Time Series Extraction of ${SEEDNAME} -- Result exists!"
    fi

    # regexp note: g and I flags denote (g) apply globally (all match instances) and (I) apply to all letter cases
    cd ${RESULT_PATH}
    if [ ! -d ${OUTPUT_DIR} ]; then
      # determine number of volumes for each run
      IMGPATH=${NUI_PATH}/stats/scaled_${FILEN}
      NUMVOL=`fslnvols ${IMGPATH}`
      VOLINFO=(`fslstats ${IMGPATH} -v`)
      TRINFO=(`fslinfo ${IMGPATH}|grep pixdim4`)
      sed -e "s#=IMGPATH#${IMGPATH}#" -e "s#=OUTPUT_DIR#${OUTPUT_DIR}#" -e "s#=FSL_PATH#${FSL_PATH}#" -e "s#=DATA_PATH#${DATA_PATH}#" -e "s#=NVOL#${NUMVOL}#" -e "s#=NUMTR#${TRINFO[1]}#" -e "s#=TOTALVOX#${VOLINFO[0]}#" -e "s#=INPUT_FILE#norm_${SEED_FILE}#" $FEAT_TEMPLATE_PATH > ${DATA_PATH}/$OUTFILE
      echo "Running FEAT on $SUB, session $i"
      feat ${DATA_PATH}/$OUTFILE
    else
      echo "--Skipping FEAT analysis-- Result exists!"
    fi
    
    #read -p "Press any key to continue..."
    ## Remove intermediate files
    if [ -f ${NUI_PATH}/stats/${FILEN}.nii.gz ];then rm ${NUI_PATH}/stats/${FILEN}.nii.gz; fi
    #if [ -f scaled_${FILEN}.nii.gz ];then rm scaled_${FILEN}.nii.gz; fi
    if [ -f ${DATA_PATH}/$OUTFILE ]; then rm ${DATA_PATH}/$OUTFILE; fi
    if [ -f ${DATA_PATH}/$SUB-$i-seed${SEEDNAME}.nii.gz ]; then rm ${DATA_PATH}/$SUB-$i-seed${SEEDNAME}.nii.gz; fi

    #copy registration data from registration step
    if [ ! -s ${OUTPUT_DIR}/reg/example_func2standard.mat ]; then
      echo "Copying and updating $SUB session $i registration info..."
      if [ ! -e ${OUTPUT_DIR}/reg ]; then mkdir ${OUTPUT_DIR}/reg; fi
      cp ${REG_PATH}/* ${OUTPUT_DIR}/reg
      updatefeatreg ${OUTPUT_DIR}
    else
      echo "--Did not copy registration result from registration step--  File exists!"
    fi

   #read -p "Press enter to continue.."
   done #NUI loop
  done  #subject loop

done  #frequency band loop
###END of Script
END_TIME=$SECONDS
DIFF=$[${END_TIME}-${START_TIME}]
echo "Time taken: $[$DIFF / 3600 ] hours $[($DIFF % 3600) / 60] minutes $[$DIFF % 60] seconds"

