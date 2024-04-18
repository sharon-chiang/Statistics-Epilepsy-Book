#These args are essential and standard
NOW=$(date +'%Y_%m_%d__%H_%M_%S_%Z')

VERSION=1

EXPERIMENT_NAME='epilepsy_experiment'
DATASET_DIR='resources/datasets/personal/epilepsy/financial_impact_epilepsy_general.csv' #If training, this is the training directory. If evaluating, this is the directory of files over which to run evaluation.
CONFIG='src/config/config_epilepsy_small.json' #If training, make sure this matches the data loader you're using for training ETL. If evaluating, make sure this matches the data loader you're using for evaluation ETL.
OUTPUT_DIR='outputs/epilepsy' # Used as output dir in training mode and as a model directory in eval mode

python -m train \
    --experiment_name $EXPERIMENT_NAME \
    --version $VERSION \
    --output_dir $OUTPUT_DIR \
    --time $NOW \
    --config $CONFIG \
    --data_dir $DATASET_DIR
