#!/bin/sh
#$ -cwd
#$ -j y
#$ -S /bin/sh
#$ -V

START_TIME=$SECONDS
### Filename: Bandpass_extract_timeseries_2022.sh
### Extract time series from BOLD file
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


NUI_DIR=RS-nuisance-SegCSFWM-eigen-motionscrubbed.feat
OUT_PATH=${DOC_PATH}/Outgoing/Result_FIXICA_denoise_nuisance_regression

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
    FILEO=res4d
    FILEN=res4d_${BNAME[$j]}    
    REG_PATH=${RESULT_PATH}/${SUB}-$i-mel-reg-mcf.ica/reg
    NUI_PATH=${RESULT_PATH}/${SUB}-$i-${NUI_DIR}
 
    echo "Working on $SUB session ${i} frequency band: ${BNAME[$j]}"
 
    cd ${NUI_PATH}/stats
    if [ ! -f scaled_${FILEN}.nii.gz ]; then
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

    ## Transform mask to MNI 2mm space
    if [ ! -f Shen2bold_masked.nii.gz ]; then
      echo "Transforming Shen atlas to BOLD ${i} space and masking..."
      if [ ! -f ${REG_PATH}/standard2example_func_warp.nii.gz ]; then
        echo "Generating inverse warp for $SUB session $i..."
        invwarp --ref=${REG_PATH}/example_func --out=${REG_PATH}/standard2example_func_warp --warp=${REG_PATH}/example_func2standard_warp
      fi
      applywarp --ref=scaled_${FILEN} --in=${ATLAS_PATH}/Shen_fconn_atlas_150_2mm --out=Shen2bold --warp=${REG_PATH}/standard2example_func_warp --interp=nn
      fslmaths Shen2bold -mas mask Shen2bold_masked -odt input
    else
      echo "--Skipping Transformation and atlas masking--  Result exists!"
    fi  

    ##extract time series
    if [ ! -f scaled_${FILEN}_Shen_ts.txt ]; then
      echo "Extracting residuals to Shen atlas ROIs for SUB $SUB..."
      fslmeants -i scaled_${FILEN} -o scaled_${FILEN}_Shen_ts.txt --label=Shen2bold_masked.nii.gz
    else
      echo "--Skipping Time Series Extraction-- Result exists!"
    fi

    ## Remove intermediate files
    if [ -f ${NUI_PATH}/stats/${FILEN}.nii.gz ];then rm ${NUI_PATH}/stats/${FILEN}.nii.gz; fi
    #if [ -f scaled_${FILEN}.nii.gz ];then rm scaled_${FILEN}.nii.gz; fi

    ## copy results to outgoing folder
    if [ ! -e ${OUT_PATH}/${BNAME[$j]} ]; then mkdir -p ${OUT_PATH}/${BNAME[$j]}; fi
    if [ ! -f ${OUT_PATH}/${BNAME[$j]}/${SUB}_${i}.txt ] ; then
      echo "Copying results to outgoing folder for SUB $SUB..."
      cp scaled_${FILEN}_Shen_ts.txt ${OUT_PATH}/${BNAME[$j]}/${SUB}_${i}.txt
    else
      echo "--Skipping copy--  Result exists!"
    fi


    #read -p "Press enter to continue.."

   done #NUI loop
  done  #subject loop
done  #frequency band loop
###END of Script
END_TIME=$SECONDS
DIFF=$[${END_TIME}-${START_TIME}]
echo "Time taken: $[$DIFF / 3600 ] hours $[($DIFF % 3600) / 60] minutes $[$DIFF % 60] seconds"

