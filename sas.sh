#!/bin/bash

mkdir -p sas

rm -f columns

while read n word 
do
  echo "--- $n ---"
  rg -w $word tweets/types.txt | cut -d'|' -f1 | sed -e "s/$/ "$n" 1/" >> columns 
done < selectedwords

sort columns | uniq > a ; mv a columns  # to avoid words whose accents were stripped to be duplicated in the same text ; SAS can't handle that

#cut -d' ' -f2 tweets/selectedwords | gwc -L 
#head -1 columns | cut -d' ' -f1 | gwc -L

cp columns sas/data.txt

cut -d' ' -f1,3 file_index.txt | sed 's/d://' | tr '-' ' ' > sas/dates.txt

python3 wcount.py
