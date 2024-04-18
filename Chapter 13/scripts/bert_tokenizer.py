from transformers import BertTokenizer

sample = "After a temporal lobe resection, the atonic and clonic seizure frequency fell by 50%."

bert_tokenizer = BertTokenizer.from_pretrained("bert-base-uncased")

encoded_ids = bert_tokenizer.encode(sample)
encoded_tokens = bert_tokenizer.convert_ids_to_tokens(encoded_ids)

for token, id in zip(encoded_tokens, encoded_ids):
    print("{}: {}".format(token, id))