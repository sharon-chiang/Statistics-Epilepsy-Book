import spacy

sample = "After a temporal lobe resection, the atonic and clonic seizure frequency fell by 50%."

nlp = spacy.load("en_core_web_sm")
english_vocab = set(nlp.vocab.strings)
spacy_document = nlp(sample)

for token in spacy_document:
    found = "found" if token.text in english_vocab else "NOT FOUND"
    print("{}: {}".format(token.text, found))
