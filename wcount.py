import nltk
from nltk.tokenize import word_tokenize
nltk.download('punkt_tab')

# Read input file
with open('tweets/tweets.txt', 'r') as f:
    lines = f.readlines()

# Process lines and count words
word_counts = []
for line in lines:
    fields = line.strip().split('|')
    if len(fields) > 1:
        text = fields[4]
        words = word_tokenize(text)
        word_count = len([word for word in words if word.isalnum()])  # Count alphanumeric words
        id = fields[0]  # Use the entire first field as the ID
        word_counts.append((id, word_count))

# Write output to file
with open('sas/wcount.txt', 'w') as f:
    for id, count in word_counts:
        f.write(f"{id} {count}\n")

print("Word counts written to sas/wcount.txt")
