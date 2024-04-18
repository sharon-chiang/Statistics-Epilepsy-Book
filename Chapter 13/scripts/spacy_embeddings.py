import spacy

sample_words = ["epilepsy", "seizure", "patient", "language"]

nlp = spacy.load("en_core_web_md")
docs = [nlp(sample) for sample in sample_words]

# Spacy's Medium English Model Stores Words As Vectors of Dimension 300
# Note each word has this vector size
for doc in docs:
    assert doc.vector.shape[0] == 300

# The cosine distance, ranging from [0,1], of the vectors tells us how similar the words are
print(docs[0].similarity(docs[1]))  # epilepsy and seizure -> 0.9999
print(docs[0].similarity(docs[2]))  # epilepsy and patient -> 0.4434
print(docs[0].similarity(docs[3]))  # epilepsy and language -> 0.1273
