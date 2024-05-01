#!/bin/bash

#cut -d'|' -f2 tweets/types.txt | sed 's/^c://' | tr ' ' '\n' | tr '[:upper:]' '[:lower:]' | grep '[a-z]' | sort | uniq -c | sort -nr | sed 's/^[ ]*//' | rg -v '^[123] ' | tr -dc '[:lower:][0-9][:punct]_\n ' | sed -f stoplist.sed > wordlist

# Note: The command " tr -dc '[:lower:][0-9][:punct]_\n ' " causes the removal of accented characters such as '[áàãéíóõúç]' and brings no apparent benefit to the analysis

cut -d'|' -f2 tweets/types.txt | sed 's/^c://' | tr ' ' '\n' | tr '[:upper:]' '[:lower:]' | grep '[a-z]' | sort | uniq -c | sort -nr | sed 's/^[ ]*//' | rg -v '^[123] ' | sed -f stoplist.sed > wordlist

head -1000 wordlist | cut -d' ' -f2 | nl -nrz | tr '\t' ' ' | sed 's/^/v/' > selectedwords

cp selectedwords var_index.txt
