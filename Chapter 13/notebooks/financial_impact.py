# %%
import os

import hdbscan
import matplotlib.pyplot as plt
import numpy as np
import pandas as pd
import plotly.express as px
import torch
import umap
from sentence_transformers import SentenceTransformer
from sklearn.feature_extraction.text import CountVectorizer
from sklearn.manifold import TSNE
from tqdm import tqdm
from transformers import AutoModelForSeq2SeqLM, AutoTokenizer

pd.set_option("max_colwidth", 400)
pd.set_option("display.max_rows", None)

# %% [markdown]
#  # Load Data

# %%
df = pd.read_csv(
    f"{os.environ['HOME']}/projects/epilepsy/datasets/Financial_Surgery.csv",
    encoding="mac_roman",
)
df = df.rename(
    columns={
        "Do you have any comments on the financial impact of epilepsy?": "finance",
        "Do you have any comments about brain surgery in general?": "general",
    }
)
df.shape

# %% [markdown]
#  # Clustering

# %%
model = SentenceTransformer("distilbert-base-nli-mean-tokens")
embeddings = model.encode(df["finance"], show_progress_bar=True)
embeddings.shape

# %%
umap_embeddings = umap.UMAP(n_neighbors=5, n_components=2, metric="cosine").fit_transform(
    embeddings
)
cluster = hdbscan.HDBSCAN(
    min_cluster_size=2, metric="euclidean", cluster_selection_method="eom"
).fit(umap_embeddings)
umap_embeddings.shape, np.unique(cluster.labels_)

# %%
# Prepare data
umap_data = umap.UMAP(n_neighbors=5, n_components=2, min_dist=0.0, metric="cosine").fit_transform(
    embeddings
)
result = pd.DataFrame(umap_data, columns=["x", "y"])
result["labels"] = cluster.labels_

# Visualize clusters
fig, ax = plt.subplots(figsize=(20, 10))
outliers = result.loc[result.labels == -1, :]
clustered = result.loc[result.labels != -1, :]
plt.scatter(outliers.x, outliers.y, color="#BDBDBD", s=0.05)
plt.scatter(clustered.x, clustered.y, c=clustered.labels, s=0.05, cmap="hsv_r")
plt.colorbar()

df["umap_x"] = umap_data[:, 0]
df["umap_y"] = umap_data[:, 1]
df["cluster"] = cluster.labels_

# %%
tsne = TSNE(n_components=2, learning_rate="auto", init="pca", n_iter=2000)
tsne_factors = tsne.fit_transform(embeddings)
df["tsne_x"] = tsne_factors[:, 0]
df["tsne_y"] = tsne_factors[:, 1]

# %%
fig = px.scatter(
    df,
    x="umap_x",
    y="umap_y",
    color="cluster",
    hover_name="finance",
    title="t-SNE",
    width=1200,
    height=800,
)
fig.show()

# %% [markdown]
#  # Cluster Names

# %%
docs_df = pd.DataFrame(df, columns=["finance", "cluster"])
docs_df["id"] = range(len(docs_df))
docs_per_topic = docs_df.groupby(["cluster"], as_index=False).agg({"finance": " ".join})

# %%
def c_tf_idf(documents, m, ngram_range=(1, 1)):
    count = CountVectorizer(ngram_range=ngram_range, stop_words="english").fit(documents)
    t = count.transform(documents).toarray()
    w = t.sum(axis=1)
    tf = np.divide(t.T, w)
    sum_t = t.sum(axis=0)
    idf = np.log(np.divide(m, sum_t)).reshape(-1, 1)
    tf_idf = np.multiply(tf, idf)

    return tf_idf, count


tf_idf, count = c_tf_idf(docs_per_topic["finance"].values, m=len(df))

# %%
def extract_top_n_words_per_topic(tf_idf, count, docs_per_topic, n=20):
    words = count.get_feature_names()
    labels = list(docs_per_topic.cluster)
    tf_idf_transposed = tf_idf.T
    indices = tf_idf_transposed.argsort()[:, -n:]
    top_n_words = {
        label: [(words[j], tf_idf_transposed[i][j]) for j in indices[i]][::-1]
        for i, label in enumerate(labels)
    }
    return top_n_words


def extract_topic_sizes(df):
    topic_sizes = (
        df.groupby(["cluster"])
        .finance.count()
        .reset_index()
        .rename({"cluster": "cluster", "finance": "Size"}, axis="columns")
        .sort_values("Size", ascending=False)
    )
    return topic_sizes


top_n_words = extract_top_n_words_per_topic(tf_idf, count, docs_per_topic, n=20)
topic_sizes = extract_topic_sizes(docs_df)
topic_sizes.head(10)

# %%
top_n_words.keys()

# %%
for cluster in top_n_words.keys():
    print(f"Cluster: {cluster}")
    print(top_n_words[cluster][:5])

# %% [markdown]
#  # Paraphrase

# %%
device = "cuda" if torch.cuda.is_available() else "cpu"
tokenizer = AutoTokenizer.from_pretrained("Vamsi/T5_Paraphrase_Paws")
model = AutoModelForSeq2SeqLM.from_pretrained("Vamsi/T5_Paraphrase_Paws").to(device)

# %%
paraphrases = []
for _, row in tqdm(df.iterrows(), total=df.shape[0]):
    text = "paraphrase: " + row["finance"] + " </s>"
    encoding = tokenizer.encode_plus(text, pad_to_max_length=True, return_tensors="pt")
    input_ids, attention_masks = encoding["input_ids"].to(device), encoding["attention_mask"].to(
        device
    )

    outputs = model.generate(
        input_ids=input_ids,
        attention_mask=attention_masks,
        max_length=128,
        do_sample=True,
        top_k=120,
        top_p=0.95,
        early_stopping=True,
        num_return_sequences=1,
        temperature=1.0,
    )
    paraphrases.append(
        tokenizer.decode(outputs[0], skip_special_tokens=True, clean_up_tokenization_spaces=True)
    )
df["finance_paraphrased"] = paraphrases
df[["finance", "finance_paraphrased"]]

# %%
