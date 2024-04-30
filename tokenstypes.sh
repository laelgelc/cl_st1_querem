#!/bin/bash

# speed: 1,000 texts = 28 sec 

rm -f tweets/tokens.txt tweets/types.txt

last=$( wc -l file_index.txt | tr -dc '[0-9]' )

while read text conversation date user url 
do
  echo "--- tokenstypes $text / $last ---"
  rg $text tweets/tagged.txt | cut -d'|' -f5 | sed 's/c://' | tr '~' '\n' | rg  '	VERB|	ADJ|	NOUN|	HASHTAG|	EMOJI' | rg -v -e '<unknown>' -e '\&amp' | cut -f3 | rg -v '^_h' | sed -e "s/\([\*\.\!?,'/()\":;$\-]\)/ \1 /g" | tr ' ' '\n' | rg '[a-z]' | rg -v '^.$' > b
  sed -e '/^ser$/d' -e '/^estar$/d' -e '/^haver$/d' b | tr '\n' ' ' | tr -d '#' | tr '[:upper:]' '[:lower:]' | tr -s ' ' | sed "s/^/"$text"|c:/" >> tweets/tokens.txt
  echo >> tweets/tokens.txt
  tr -d '#' < b | tr '[:upper:]' '[:lower:]' | sort | uniq | tr '\n' ' ' | tr -s ' ' | sed "s/^/"$text"|c:/" >> tweets/types.txt
  echo >> tweets/types.txt
done < file_index.txt
