import argparse
import json
import logging
import os
from typing import Tuple

import torch
from data.financial_impact import FinancialImpactDataModule
from pytorch_lightning import LightningDataModule, LightningModule

from sheepy.common.timestamp import get_timestamp_now
from sheepy.experiment.base_experiment import Experiment
from sheepy.experiment.sweep_experiment import SweepExperiment
from sheepy.models import MODEL_MAPPING

logger = logging.getLogger("epilepsy")

DATA_MODULE_MAPPING = {
    "financial_impact": FinancialImpactDataModule,
}


def get_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser()

    # The config file below specifies values for all arguments listed in this function
    # TODO - some these can be moved to a config, such as fp16
    parser.add_argument(
        "--config", required=True, type=str, help="Location of experiment config profile JSON."
    )
    parser.add_argument(
        "--fp16",
        action="store_true",
        help="Enables 16-bit floating-point precision during training on GPU's if available",
    )
    parser.add_argument(
        "--data_format",
        type=str,
        default="csv",
        help="Data format of input file/s, must be either csv or json",
    )
    parser.add_argument(
        "--evaluate",
        action="store_true",
        help="Runs the model in batch evaluation mode on a text file instead of the train/val/test mode.",
    )
    parser.add_argument(
        "--evaluate_batch_file",
        type=str,
        default=None,
        help="Location of the text file with which to run batch evaluation.",
    )
    parser.add_argument(
        "--evaluate_live",
        action="store_true",
        help="Runs the model in raw input evaluation mode from the shell instead of the train/val/test mode or batch evaluation mode",
    )
    parser.add_argument(
        "--tune",
        action="store_true",
        help="Runs the model in tune/sweep mode as per the sweep argument of the config file.",
    )
    parser.add_argument(
        "--output_dir",
        type=str,
        default=None,
        help="In training mode, this is the name of the directory used to output the results of your experiment. In evaluation mode, this is the directory where you want to load your experiment.",
    )
    parser.add_argument(
        "--output_key",
        type=str,
        default=None,
        help="Name of the output column or dict key. Used only in evaluation mode",
    )
    parser.add_argument(
        "--pretrained_dir",
        type=str,
        default=None,
        help="Name of the directory with pretrained model. Used only in evaluation mode",
    )
    return parser


def load_config() -> Tuple[argparse.Namespace, LightningDataModule, LightningModule]:
    parser = get_parser()
    args, _ = parser.parse_known_args()

    with open(args.config, "r") as f:
        config = json.load(f)
        try:
            data_module_key = config["experiment"]["data_module"]
            model_key = config["experiment"]["model"]
            data_module = DATA_MODULE_MAPPING[data_module_key]
            model = MODEL_MAPPING[model_key]
        except KeyError:
            raise KeyError(
                "You must pass both a 'data_module' and 'model' argument to the config file under "
                "the 'experiment' key object, and these must be mapped in the module_mappings.py file"
            )

    if args.tune and args.evaluate:
        raise ValueError(
            "You cannot run the model with both tune and evaluate mode turned on. Pick one or the "
            "other, or neither if you want to just train."
        )

    parser = data_module.add_model_specific_args(parser)
    parser = model.add_model_specific_args(parser)
    parser = Experiment.add_model_specific_args(parser)

    # Use the environment to verify a few additional arguments
    args = parser.parse_args()
    args.time = get_timestamp_now()
    args.output_dir = args.output_dir.replace("~", os.environ["HOME"])
    args.data_dir = args.data_dir.replace("~", os.environ["HOME"])
    logger.info(json.dumps(vars(args), indent=4))
    return args, data_module, model


def main():
    args, data_module, model = load_config()

    args = Experiment.validate_experiment_args(args)

    args.n_gpu = torch.cuda.device_count()
    args.precision = 16 if args.fp16 and args.n_gpu > 0 else 32

    # Load up an experiment and make sure config is okay for it. We always call config
    if args.tune:
        experiment = SweepExperiment(args, data_module, model)
        experiment.tune()
    else:
        experiment = Experiment(args)
        if args.evaluate:
            experiment.prepare_evaluator(data_module, model)
            if args.evaluate_live:
                while True:
                    experiment.predict_live()
            else:
                experiment.predict_batch()
        else:
            experiment.prepare_trainer(data_module, model)
            experiment.train()
            # experiment.test()


if __name__ == "__main__":
    main()
