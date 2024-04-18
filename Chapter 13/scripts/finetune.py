
import evaluate
import numpy as np
import pandas as pd
from datasets import Dataset
from transformers import (
    AutoModelForSequenceClassification,
    AutoTokenizer,
    Trainer,
    TrainingArguments,
    pipeline,
)

df = pd.read_csv("/home/rob/Documents/financial_surgery.csv", header=0)
df = df[["financial_impact", "employment_burden"]]
df["label"] = df["employment_burden"].astype("int32")
df = df.sample(frac=1, random_state=123456).reset_index(drop=True)

print("Building Roberta Model To Fine-Tune Classifier")
tokenizer = AutoTokenizer.from_pretrained("roberta-base")

# Create vanilla fine-tuner
model = AutoModelForSequenceClassification.from_pretrained("roberta-base", num_labels=2)
training_args = TrainingArguments(
    output_dir="financial_impact_trainer",
    save_total_limit=2
)

# Create some metrics we care about for classification
metric_precision = evaluate.load("precision")
metric_recall = evaluate.load("recall")
metric_f1 = evaluate.load("f1")
metric_accuracy = evaluate.load("accuracy")


def tokenize_function(samples):
    return tokenizer(samples["financial_impact"], padding="max_length", truncation=True)

# Create metrics function to run in trainer


def compute_metrics(eval_pred):
    logits, labels = eval_pred
    predictions = np.argmax(logits, axis=-1)

    precision = metric_precision.compute(predictions=predictions, references=labels)["precision"]
    recall = metric_recall.compute(predictions=predictions, references=labels)["recall"]
    f1 = metric_f1.compute(predictions=predictions, references=labels)["f1"]
    accuracy = metric_accuracy.compute(predictions=predictions, references=labels)["accuracy"]

    return {"precision": precision, "recall": recall, "f1": f1, "accuracy": accuracy}


def get_indexes_except(num, target):
    return [index for index in range(num) if index != target]


# Split dataset into 5 folds, and loop through trainer for each fold as a holdout
N_FOLDS = 5
dfs = np.array_split(df, N_FOLDS)

for i in range(N_FOLDS):
    train_indexes = get_indexes_except(N_FOLDS, i)
    train_df = pd.concat([dfs[idx] for idx in train_indexes])
    test_df = dfs[i]

    train_df = train_df.reset_index(drop=True)
    test_df = test_df.reset_index(drop=True)

    train_dataset = Dataset.from_pandas(train_df)
    test_dataset = Dataset.from_pandas(test_df)

    train_dataset = train_dataset.map(tokenize_function, batched=True)
    test_dataset = test_dataset.map(tokenize_function, batched=True)

    # Fine tune
    training_args = TrainingArguments(
        output_dir=f"financial_impact_trainer_fold_{i}", evaluation_strategy="epoch", num_train_epochs=2)

    print(f"Beginning Fine-Tuning Fold {i+1} of {N_FOLDS}")
    trainer = Trainer(
        model=model,
        args=training_args,
        train_dataset=train_dataset,
        eval_dataset=test_dataset,
        compute_metrics=compute_metrics,
    )

    trainer.train()
