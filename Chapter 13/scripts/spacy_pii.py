import spacy

sample = "The patient, John Smith, began feeling symptoms at his home in Seattle, and was taken to Virginia Mason Medical Center for treatment"
nlp = spacy.load("en_core_web_md")

doc = nlp(sample)

for word in doc.ents:
    sample = sample.replace(word.text, word.label_)

print(sample)
# The patient, PERSON, began feeling symptoms at his home in GPE, and was taken to ORG for treatment
