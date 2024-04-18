import argparse
import logging
from typing import Optional

from pytorch_lightning import LightningDataModule
from torch.utils.data import DataLoader, Dataset

logger = logging.getLogger("epilepsy")


class SUDEPDataModule(LightningDataModule):
    def __init__(self, hparams: argparse.Namespace) -> None:
        super().__init__()
        self.hparams.update(vars(hparams))

    def prepare_data(self) -> None:
        pass

    def setup(self, stage: Optional[str] = None) -> None:
        pass

    def train_dataloader(self) -> DataLoader:
        self._get_dataloader("train", self.hparams.train_batch_size, shuffle=True)

    def val_dataloader(self) -> DataLoader:
        self._get_dataloader("val", self.hparams.eval_batch_size, shuffle=False)

    def test_dataloader(self) -> DataLoader:
        self._get_dataloader("test", self.hparams.eval_batch_size, shuffle=False)

    def _get_dataloader(self, mode: str, batch_size: int, shuffle: bool = False) -> DataLoader:
        dataset = Dataset()

        return DataLoader(
            dataset=dataset,
            batch_size=batch_size,
            shuffle=shuffle,
            num_workers=self.hparams.num_workers,
        )
