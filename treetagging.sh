#!/bin/bash

# speed: 150 lines = 14 sec

last=$( tac file_index.txt | head -1 | cut -d' ' -f1 )

rm -f tweets/tagged.txt  ### WATCH THIS!

while read text conversation date user url 
do
  echo "--- treetagging $text / $last ---"
  rg $text tweets/tweets.txt | tr '|' '\n' | rg -v '^c:' > a
  rg $text tweets/tweets.txt | cut -d'|' -f5 | sed 's/^c://' | tree-tagger-portuguese2 | sed -e '/^@/s/\(.*\)	\(.*\)	\(.*\)/\1	\2	twitterhandle/' -e '/<unknown>$/s/\(.*\)	\(.*\)	\(.*\)/\1	\2	\1/' -e '/^EMOJI/s/\(EMOJI_\)\(.*\)	\(.*\)	\(EMOJI_\)\(.*\)/\2	EMOJI	\L\5/g' -e '/^HASHTAG/s/\(HASHTAG\)\(#\)\(.*\)	\(.*\)	\(HASHTAG\)\(#\)\(.*\)/\2\3	HASHTAG	\L\7/' -e 's/\(.*\)	\(.*\)	\(.*\)/\1	\2	\L\3/' | tr '\n' '~' | sed 's/^/c:/' >> a
  tr '\n' '|' < a | sed 's/~$//' >> tweets/tagged.txt
  echo >> tweets/tagged.txt 
done < file_index.txt
