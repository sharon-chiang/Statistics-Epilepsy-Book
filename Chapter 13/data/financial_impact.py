import argparse
import os

import pandas as pd

from sheepy.common.df_ops import split_dataframes
from sheepy.data_modules.multi_label_csv_data_module import MultiLabelCSVDataModule


class FinancialImpactDataModule(MultiLabelCSVDataModule):
    """
    DataLoader based on the multilabel csv data module provoiding an example of multi label ETL
    """

    def __init__(self, args):
        super().__init__(args)
        self._train_dataset, self._val_dataset, self._test_dataset = None, None, None

    def _read_dataset(self, data_dir: str) -> pd.DataFrame:
        """[summary]ValueError: The implied number of classes (from shape of inputs) does not match num_classes.

        Args:
            data_dir (str): [description]

        Returns:
            pd.DataFrame: [description]
        """
        pass

    def prepare_data(self, stage=None):
        """[summary]

        Args:
            stage ([type], optional): [description]. Defaults to None.
        """
        pass

    def setup(self, stage=None):
        """[summary]

        Args:
            stage ([type], optional): [description]. Defaults to None.

        Returns:
            [type]: [description]
        """
        self.all_dataframes = None
        self.test_dataframes = []
        if stage == "fit" or stage is not None:
            self.train_dataframes = self._read_csv_directory(self.args.data_dir)

            for label in self.args.label:
                self.train_dataframes[0][label] = self.train_dataframes[0][label].map(
                    {"nan": "0", 1.0: "1", "1.0": "1"}
                )
            self._train_dataset, self._val_dataset, self._test_dataset = split_dataframes(
                self.train_dataframes,
                train_ratio=self.args.train_ratio,
                validation_ratio=self.args.validation_ratio,
                test_ratio=self.args.test_ratio,
                shuffle=True,
            )

            self._train_dataset = self._resample_positive_rows(self._train_dataset)

            self.logger.info(
                "Dataset split complete. (Total) Dataset Shapes:\n\tTrain: {}\n\tValidation: {}\n\tTest: {}".format(
                    self._train_dataset.shape, self._val_dataset.shape, self._test_dataset.shape
                )
            )

            train_label_size_out = "Training Dataset Sample Size For Each Label:\n"
            for label in self.args.label:
                support = self._train_dataset[self._train_dataset[label] == "1"].shape[0]
                train_label_size_out += "\t{}: {} samples ({} %)\n".format(
                    label, support, round(100 * support / self._train_dataset.shape[0], 4)
                )
            self.logger.info(train_label_size_out)

            self._test_dataset[self.sample_id_col] = range(len(self._test_dataset))

        else:  # evaluating
            if self._test_dataset is None:
                for f in os.listdir(self.args.data_dir):
                    if f.endswith(".txt"):
                        self.test_dataframes.append(
                            self._read_evaluation_file(os.path.join(self.args.data_dir, f))
                        )
                self._test_dataset = pd.concat(self.test_dataframes)
                self._test_dataset[self.sample_id_col] = range(len(self._test_dataset))
                self.logger.info(
                    "In evaluation mode. Dataset Shapes:\n\tTest: {}".format(
                        self._test_dataset.shape
                    )
                )

    @classmethod
    def add_model_specific_args(cls, parser: argparse.ArgumentParser) -> argparse.ArgumentParser:
        """Return the argument parser with necessary args for this class appended to it"""
        parser.add_argument(
            "--data_dir",
            type=str,
            required=False,
            help="If all of your data is in one folder, this is the path to that directory containing the csvs, or alternatively a single csv file",
        )
        return parser
