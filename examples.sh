#!/bin/bash

# enter project name
project=cl_st1_querem

# enter how many examples to be picked for each pole:    
pickexamples=50

mkdir -p examples/base
rm -f examples/examples_*
rm -f examples/base/*

sort -k2,2 var_index.txt | cut -f2 > kw_index.txt

html2text -nobs sas/output_"$project"/loadtable.html > a

# The following block results in errors when run on a Linux Ubuntu system. It has been refactored as follows
#rm -f x??
#split -p'=====' a
#ls x?? > xfiles

rm -f xx??
csplit a '/=====/+1' '{*}'
ls xx?? > xfiles

while read xfile
do
  pole=$( grep '^Factor ' $xfile | cut -d' ' -f2,3 | sed -e 's/^/f/' -e 's/ //g' )
#  grep '^[0-9]' $xfile | tr -dc '[:alpha:][:punct:][0-9]\n ' | sed 's/^/~/' | tr  '[:space:]()' ' ' | tr -s ' ' |  tr '~' '\n' | cut -d' ' -f2 | grep -v '^$' | sed "s/^/$pole /" 
#  grep '^[0-9]' $xfile | sed 's/)/ secondary/' | tr -dc '[:alpha:][:punct:][0-9]\n ' | sed 's/^/~/' | tr  '[:space:]()' ' ' | tr -s ' ' |  tr '~' '\n' | cut -d' ' -f2,4 | sed 's/ secondary/ (secondary)/' | grep -v '^$' | sed "s/^/$pole /" 
  grep '^\s*[0-9]' $xfile | sed 's/)/ secondary/' | tr -dc '[:alpha:][:punct:][0-9]\n ' | sed 's/^/~/' | tr  '[:space:]()' ' ' | tr -s ' ' |  tr '~' '\n' | cut -d' ' -f3,5 | sed 's/ secondary/ (secondary)/' | grep -v '^$' | sed "s/^/$pole /" 
done < xfiles > examples/factors
##rm -f x??
rm -f xx??

head -1  sas/output_"$project"/"$project"_scores.tsv | tr -d '\r' | tr '\t' '\n' > vars

last=$( cut -d' ' -f1 examples/factors | tr -dc '[0-9\n]' | sort | uniq | sort -nr | head -1 )

for i in $(eval echo {1..$last});
#for i in {1..6}
do
  column=$( echo " $i + 1 " | bc ) 
  cut -f1,"$column"  sas/output_"$project"/"$project"_scores_only.tsv | tail +2 > a

  for pole in pos neg
  do
    echo "--- examples "f"$i""$pole"" ---" 

    if [ "$pole" == pos ] ; then
       sort -nr -k2,2 a | grep -v '\-' | head -"$pickexamples" | nl -nrz > files
    else
       sort -n -k2,2 a | grep '\-' | head -"$pickexamples" | nl -nrz > files
    fi

    grep f"$i""$pole" examples/factors | sort -t' ' -k2,2 | cut -d' ' -f2- | sort > factor_words  # the words loading on this factor


    while read n file score
    do

        textid=$file
        conversation=$( rg $file file_index.txt | cut -d' ' -f2 | sed 's/v://' )
        date=$( rg $file file_index.txt | cut -d' ' -f3 | sed 's/d://' )
        user=$( rg $file tweets/tweets.txt | cut -d'|' -f4 | sed 's/u://' )
        url=$( rg $file file_index.txt | cut -d' ' -f4 | sed 's/url://' )

      # REGARDLESS OF FACTOR -- FACTOR FILTERING OCCURS FURTHER DOWN:
      grep -m1 $file  sas/output_"$project"/"$project"_scores.tsv | tr -d '\r' | tr '\t' '\n' > scores # var values for this text, incl. 0
      paste vars scores | tr '\t' ' ' | grep '^v' | grep -v ' 0$' | cut -d' ' -f1 | sort  > vars_text # var labels for this text, ie not 0
      join vars_text var_index.txt | cut -d' ' -f2 | sort > vars_text_codes # words that occur in this text 
      
      # the word forms and lemmas for the text:
      rg $textid tweets/tagged.txt | tr '~' '\n' | cut -f1,3 | tr '\t' ' ' | cut -d'|' -f5 | sed 's/c://' | grep -v '^$' > examples/base/"$file".txt

      #echo "---------------" 
      
      wordsloading=$( join vars_text_codes factor_words | wc -l | tr -dc '[0-9]' ) 
      wordcount=$( rg $file sas/wcount.txt | cut -d' ' -f2 | tr -dc '[0-9]' )

      echo "--- factor $i $pole # $n ---" 
      echo "file = $file" > e
      echo "date = $date" >> e
      echo "user = $user" >> e
      echo "conversation = $conversation" >> e
      echo "URL = $url" >> e
      echo >> e

      echo "word count = $wordcount" >> e
      echo "words loading = $wordsloading" >> e
      
      
      echo "factor score = $score" >> e
      echo >> e

      # FILTERING THE WORDS OCCURRING IN THIS TEXT BY THE WORDS LOADING ON THIS FACTOR
      join vars_text_codes factor_words | cut -d' ' -f1 | sed 's;\(.*\);/ \1$/s/~(.*~) ~(.*~)/**~1**/;' | tr '~' '\' > ascii.sed
      sed -f ascii.sed examples/base/"$file".txt | cut -d' ' -f1 | tr '\n' ' ' | tr -s ' ' | sed 's/\([a-zA-Z]\) \([.,;:!?]\)/\1\2/g' | fold -s >> e
                  
      echo >> e
      echo >> e
      echo "Lemmas in this text that loaded on the factor:" >> e
      echo >> e

      join vars_text_codes factor_words >> e # FILTERING THE WORDS OCCURRING IN THIS TEXT BY THE WORDS LOADING ON THIS FACTOR

      mv e examples/examples_f"$i"_"$pole"_"$n".txt

    done < files 

  done

done

#rm -f vars factor_words scores vars_text vars_text_codes
