#!/bin/sh
#$ -cwd
#$ -j y
#$ -S /bin/sh
#$ -V

START_TIME=$SECONDS
### Filename: Runlevel3_2022.sh
### This script runs a higher-level analysis to combine multiple sessions
### Author: Hsiang Yeh
### email: shawn.j.yeh@gmail.com

# Files required for this step:  
#   Previously run correlation steps
#   and the suffix of the resultant folder.

### This script runs a higher-level analysis to combine multiple sessions
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
FEAT_TEMPLATE_PATH=${DOC_PATH}/scripts/fsl600_design_group_fixed_3Z_Template.fsf
SUFFIX=GPi
MODIFIER="_low"
CORR_DIR=correlation-${SUFFIX}${MODIFIER}-outliers

for ((j=1; j <= ${#SUBJECTS[@]}; j++)); do
  SUB=${SUBJECTS[$[$j-1]]}
  RESULT_PATH=${DOC_PATH}/${SUB}
  DATA_PATH=${RESULT_PATH}/nifti
  cd ${RESULT_PATH}
  SESSIONS=(`"ls" -1d ${SUB}-?-${CORR_DIR}.feat`) 
  SESSMAX=${#SESSIONS[@]}
  OUTFILE=${SUB}-group-${CORR_DIR}
 
  if [ ! -d ${RESULT_PATH}/${OUTFILE}.gfeat ]; then
    ### RUN within subject higher level analysis on seed location
    echo "Creating Group analysis design for $SUB..."
    scount=1
    for SESS in ${SESSIONS[@]}; do
    STMP=${SESS#${SUB}-}
    i=${STMP%-${CORR_DIR}.feat}  #grab i from input
    echo "Adding session $i into design..."
      INPUT_DIR=${RESULT_PATH}/${SESS}

      #copy registration data from registration step
      if [ ! -s ${INPUT_DIR}/reg/example_func2standard.mat ]; then
        echo "Copying and updating $SUB session $i registration info..."
        if [ ! -e ${INPUT_DIR}/reg ]; then mkdir ${INPUT_DIR}/reg; fi
        cp ${RESULT_PATH}/$SUB-$i-mel-reg-mcf.ica/reg/* ${INPUT_DIR}/reg
        updatefeatreg ${INPUT_DIR}
      else
        echo "--Did not copy registration result from registration step--  File exists!"
      fi

      #apply Fisher's Z transform to cope file
      if [ ! -s ${INPUT_DIR}/stats/cope1_copy.nii.gz.bak ]; then
        echo "Applying Fisher's Z transform to ${INPUT_DIR}/stats/cope1.nii.gz"
        cd ${INPUT_DIR}/stats
        cp cope1.nii.gz cope1_copy.nii.gz.bak
        fslmaths cope1 -mul -1 -add 1 neg_cope1_plus1_tmp
        fslmaths cope1 -add 1 -div neg_cope1_plus1_tmp -log -mul 0.5 cope1
        rm neg_cope1_plus1_tmp*
      else
        echo "--Skipping Fisher's Z transform--  File exists!"
      fi

      #apply Fisher's Z transform to cope file
      if [ ! -s ${INPUT_DIR}/stats/cope2_copy.nii.gz.bak ]; then
        echo "Applying Fisher's Z transform to ${INPUT_DIR}/stats/cope2.nii.gz"
        cd ${INPUT_DIR}/stats
        cp cope2.nii.gz cope2_copy.nii.gz.bak
        fslmaths cope2 -mul -1 -add 1 neg_cope2_plus1_tmp
        fslmaths cope2 -add 1 -div neg_cope2_plus1_tmp -log -mul 0.5 cope2
        rm neg_cope2_plus1_tmp*
      else
        echo "--Skipping Fisher's Z transform--  File exists!"
      fi

      #set the replacement values for the template
      if [ $scount -lt $SESSMAX ]; then
         FEAT_DIR="set feat_files($scount) \"${INPUT_DIR}\"\n\n=FEAT_DIR"
         EV_VAL="set fmri(evg${scount}.1) 1\n\n=EV_VAL"
         GROUP_MEM="set fmri(groupmem.$scount) 1\n\n=GROUP_MEM"
         #FEAT_DIR="test\n=FEAT_DIR"
        #echo [ $i -lt $SESSMAX ] `[ $i -lt $SESSMAX ]` "$FEAT_DIR"
      else
        FEAT_DIR="set feat_files($scount) \"${INPUT_DIR}\""
         EV_VAL="set fmri(evg${scount}.1) 1"
        GROUP_MEM="set fmri(groupmem.$scount) 1"
        #FEAT_DIR="test"
        #echo [ $i -lt $SESSMAX ] `[ $i -lt $SESSMAX ]` "$FEAT_DIR"
      fi


      # regexp note: g and I flags denote (g) apply globally (all match instances) and (I) apply to all letter cases
      if [ $i -eq "1" ]; then
        sed -e "s#=FSL_PATH#${FSL_PATH}#" -e "s#=RESULT_PATH#${RESULT_PATH}#" -e "s#=OUT_DIR#${RESULT_PATH}/${OUTFILE}#" -e "s#=SESSMAX#${SESSMAX}#" -e "s#=SESSNUM#${i}#" -e "s#=FEAT_DIR#${FEAT_DIR}#" -e "s#=EV_VAL#${EV_VAL}#" -e "s#=GROUP_MEM#${GROUP_MEM}#" $FEAT_TEMPLATE_PATH > ${DATA_PATH}/${OUTFILE}-tmp.fsf
      else
        sed -e "s#=FEAT_DIR#${FEAT_DIR}#" -e "s#=EV_VAL#${EV_VAL}#" -e "s#=GROUP_MEM#${GROUP_MEM}#" ${DATA_PATH}/${OUTFILE}-tmp.fsf > ${DATA_PATH}/${OUTFILE}.fsf
        cp ${DATA_PATH}/${OUTFILE}.fsf ${DATA_PATH}/${OUTFILE}-tmp.fsf
      fi
      #read -p "Paused on session $i."
      scount=$[$scount + 1]
    done

    #read -p "Press RETURN to run FEAT analysis on $SUB"
    echo "Running FEAT on $SUB..."
    feat ${DATA_PATH}/${OUTFILE}.fsf
  else
    echo "${RESULT_PATH}/${OUTFILE}.gfeat exists, FEAT not run!"
  fi
  if [ -f ${DATA_PATH}/${OUTFILE}-tmp.fsf ]; then rm ${DATA_PATH}/${OUTFILE}-tmp.fsf; fi
  if [ -f ${DATA_PATH}/${OUTFILE}.fsf ]; then rm ${DATA_PATH}/${OUTFILE}.fsf; fi
  
  #apply reverse Fisher's Z
  if [ ! -f ${RESULT_PATH}/${OUTFILE}.gfeat/cope1.feat/stats/cope1_bak.nii.gz ]; then
    echo "Applying reverse Fisher's Z to cope1 of $SUB for ${SUFFIX}..."
  	cd ${RESULT_PATH}/${OUTFILE}.gfeat/cope1.feat/stats
  	cp cope1.nii.gz cope1_bak.nii.gz
	fslmaths cope1_bak -mul 2 -exp -add 1 denominator_tmp
	fslmaths cope1_bak -mul 2 -exp -sub 1 -div denominator_tmp cope1
	rm denominator_tmp*
  else
    echo "${OUTFILE}.gfeat/cope1.feat/stats/cope1_bak.nii.gz exists, reverse Fisher's Z not run!"
  fi
	
  if [ ! -f ${RESULT_PATH}/${OUTFILE}.gfeat/cope2.feat/stats/cope1_bak.nii.gz ]; then
    echo "Applying reverse Fisher's Z to cope2 of $SUB for ${SUFFIX}..."
	cd ${RESULT_PATH}/${OUTFILE}.gfeat/cope2.feat/stats
	cp cope1.nii.gz cope1_bak.nii.gz
	fslmaths cope1_bak -mul 2 -exp -add 1 denominator_tmp
	fslmaths cope1_bak -mul 2 -exp -sub 1 -div denominator_tmp cope1
	rm denominator_tmp*
  else
    echo "${OUTFILE}.gfeat/cope2.feat/stats/cope1_bak.nii.gz exists, reverse Fisher's Z not run!"
  fi
  
  #generate overlaid image from FEAT analysis
  OUTPUT_IMG=${SUB}-feat-${SUFFIX}${MODIFIER}
  cd ${DATA_PATH}
  if [ ! -e ${OUTPUT_IMG}.png ]; then
    echo "Generating images from transformed zstat..."
    overlay 0 0 ${RESULT_PATH}/${OUTFILE}.gfeat/bg_image -a ${RESULT_PATH}/${OUTFILE}.gfeat/cope1.feat/thresh_zstat1 2.0 7.0 ${RESULT_PATH}/${OUTFILE}.gfeat/cope2.feat/thresh_zstat1 2.0 7.0 ${OUTPUT_IMG}
    slicer ${OUTPUT_IMG} -S 8 1100 ${OUTPUT_IMG}.png
    rm ${OUTPUT_IMG}.nii.gz
  else
    echo "--Skipping image generation-- Result exists!"
  fi
  #read -p "Paused. Press RETURN to continue..."

done #SUBJECTS

END_TIME=$SECONDS
DIFF=$[${END_TIME}-${START_TIME}]
echo "Time taken: $[$DIFF / 3600 ] hours $[($DIFF % 3600) / 60] minutes $[$DIFF % 60] seconds"

