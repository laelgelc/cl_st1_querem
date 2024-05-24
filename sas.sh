#!/bin/bash

mkdir -p sas

rm -f columns


# Considers the quantity of variables per text unitary even if they occur only once - suitable for short texts
while read n word 
do
  echo "--- $n ---"
  rg -w "$word" tweets/types.txt | cut -d'|' -f1 | sed -e "s/$/ "$n" 1/" >> columns 
done < selectedwords

# Considers the actual quantity of variables per text - suitable for longer texts
# Initialize the output file
#> columns

# Read each line from the file "selectedwords"
#while read n word; do
#  echo "--- $n ---"
#  
#  # Process each line in "tweets/tokens.txt"
#  while read line; do
#    # Count occurrences of $word in the current line
#    line_count=$(echo "$line" | grep -wo "$word" | wc -l)
#    
#    # Append the count to the output file if it's not zero
#    if [ $line_count -gt 0 ]; then
#      echo "$line" | cut -d'|' -f1 | sed -e "s/$/ $n $line_count/" >> columns
#    fi
#  done < tweets/tokens.txt
#done < selectedwords


sort columns | uniq > a ; mv a columns  # to avoid words whose accents were stripped to be duplicated in the same text ; SAS can't handle that

#cut -d' ' -f2 tweets/selectedwords | gwc -L 
#head -1 columns | cut -d' ' -f1 | gwc -L

cp columns sas/data.txt

cut -d' ' -f1,3 file_index.txt | sed 's/d://' | tr '-' ' ' > sas/dates.txt

python3 wcount.py
