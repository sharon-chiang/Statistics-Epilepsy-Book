from typing import Dict

import pandas as pd
from inference.server import ModelServer

from sheepy.models.inference import SequenceClassificationModelRunner


class Handler:
    def __init__(self):
        self.model_runner = SequenceClassificationModelRunner("model")

    def get_probs(self, text: str, num_digits: int = 3) -> Dict[str, float]:
        df = pd.DataFrame(self.model_runner.predict(text, min_prob=0.0))
        df = df.round(num_digits)
        return dict(zip(df["label_name"], df["prob"]))

    def handle_request(self, event, context=None):
        text = event["text"]
        probs = self.get_probs(text)
        result = {
            "predictions": probs,
        }
        return result


handler = Handler()


def handle_request(event, context):
    return handler.handle_request(event, context)


if __name__ == "__main__":
    server = ModelServer(5000, handle_request)
    server.start()
