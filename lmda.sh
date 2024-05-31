#!/bin/bash

treetagging () {

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

}

tokenstypes () {

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

}

toplemmas () {

#cut -d'|' -f2 tweets/types.txt | sed 's/^c://' | tr ' ' '\n' | tr '[:upper:]' '[:lower:]' | grep '[a-z]' | sort | uniq -c | sort -nr | sed 's/^[ ]*//' | rg -v '^[123] ' | tr -dc '[:lower:][0-9][:punct]_\n ' | sed -f stoplist.sed > wordlist

# Note: The command " tr -dc '[:lower:][0-9][:punct]_\n ' " causes the removal of accented characters such as '[áàãéíóõúç]' and brings no apparent benefit to the analysis

cut -d'|' -f2 tweets/types.txt | sed 's/^c://' | tr ' ' '\n' | tr '[:upper:]' '[:lower:]' | grep '[a-z]' | sort | uniq -c | sort -nr | sed 's/^[ ]*//' | rg -v '^[123] ' | sed -f stoplist.sed > wordlist

head -1000 wordlist | cut -d' ' -f2 | nl -nrz | tr '\t' ' ' | sed 's/^/v/' > selectedwords

cp selectedwords var_index.txt

}

sas () {

mkdir -p sas

rm -f columns


# Considers the quantity of variables per text unitary even if they occur only once - suitable for short texts
while read n word 
do
  echo "--- $n ---"
  rg -w "$word" tweets/types.txt | cut -d'|' -f1 | sed -e "s/$/ "$n" 1/" >> columns 
done < selectedwords

# Considers the actual quantity of variables per text - suitable for longer texts
## Initialize the output file
#> columns
#
## Read each line from the file "selectedwords"
#while read n word; do
#  echo "--- $n ---"
#  
#  # Process each line in "tweets/tokens.txt"
#  while read line; do
#    # Count occurrences of $word in the current line
#    line_count=$(echo "$line" | rg --word-regexp --count-matches "$word") # If 'rg' finds no matches, 'line_count' is set as empty and not integer
#    
#    # Append the count to the output file if 'line_count' is integer greater than zero. In case 'rg' finds no matches, 'line_count' is set as empty and not integer and the loop will end with error '-gt: unexpected operator', but it does not matter because the purpose is served
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

}

datamatrix () {

cut -d' ' -f1 file_index.txt > file_ids.txt

mkdir -p temp

rm -f temp/*

while read n word 
do
  echo "--- $n ---"
  rg -w $n columns | sort -t' ' -k1,1 > a
  echo "$n" > temp/$n
#  join -a 1 -1 1 -2 1 -e 0 file_ids.txt a | sed "s/$/ $n 0/" | cut -d' ' -f4 >> temp/$n
  join -a 1 -1 1 -2 1 -e 0 file_ids.txt a | sed "s/$/ $n 0/" | cut -d' ' -f3 >> temp/$n
done < selectedwords

echo "--- data.csv ...---"

awk '
        FNR==1 { col++ }
        FNR>max { max=FNR }
        { l[FNR,col]=$0 }
        END {
                for (i=1;i<=max;i++) {
                        for (j=1;j<=col;j++) {
                                printf "%-50s",l[i,j]
                        }
                        print ""
                }
        }
' temp/* > u
tr -s ' ' < u | tr ' ' ',' | sed 's/,$//' > data.csv

}

correlationmatrix () {

echo "--- python correlation ... ---"

python3 corr.py > correlation

}

formats () {

nlines=$( cat file_ids.txt | wc -l | tr -dc '[0-9]' )

tail +2 correlation | tr -s ' ' | sed 's/^/CORR /' > bottom
head -1 correlation | tr -s ' ' | sed 's/^[ ]*//' | sed "s/\(v......\)/$nlines/g" | sed 's/^/N . /' > n

python3 std.py > s 
tr -s ' ' < s | cut -d' ' -f2 | grep -v 'float' | tr '\n' ' ' | sed 's/^/STD	 . /' > std 
echo >> std

python3 mean.py > m 
tr -s ' ' < m | cut -d' ' -f2 | grep -v 'float' | tr '\n' ' ' | sed 's/^/MEAN . /' > mean
echo >> mean

cat mean std n bottom > sas/corr.txt

echo "--- sas/sas/corr.txt ---"

echo "PROC FORMAT library=work ;
  VALUE  \$lexlabels" > sas/word_labels_format.sas
tr '\t' ' ' < selectedwords | sed 's/\(.*\) \(.*\)/"\1" = "\2"/' >> sas/word_labels_format.sas
echo ";
run;
quit;" >> sas/word_labels_format.sas

echo "--- sas/word_labels_format.sas ---"

}

classify () {
    
# 100 = 240 sec => 83 hours = 4 days
    
gshuf tweets/tweets.txt | head -100 | cut -d'|' -f1,5 | sed -e 's/c://' -e 's/ /~/g' -e 's/|/ /' > class

mkdir -p chatgpt/sample chatgpt/output
rm -f chatgpt/sample/* chatgpt/output/*

while read text c
do
    echo "--- $text ---"
    cat chatgpt/template > b
    echo $c >> b
    tr '\n' ' ' < b | tr '~' ' ' >  chatgpt/sample/$text.txt
done < class

ls chatgpt/sample > files
while read file
do
    echo "--- $file ---"
    ollama run orca-mini:13b < chatgpt/sample/$file > chatgpt/output/$file
done < files

}

examples () {

# enter how many examples to be picked for each pole:    
pickexamples=50

mkdir -p examples/base
rm -f examples/examples_*
rm -f examples/base/*

sort -k2,2 var_index.txt | cut -f2 > kw_index.txt

html2text -nobs sas/output_cl_st1_querem/loadtable.html > a

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

head -1  sas/output_cl_st1_querem/cl_st1_querem_scores.tsv | tr -d '\r' | tr '\t' '\n' > vars

last=$( cut -d' ' -f1 examples/factors | tr -dc '[0-9\n]' | sort | uniq | sort -nr | head -1 )

for i in $(eval echo {1..$last});
#for i in {1..6}
do
  column=$( echo " $i + 1 " | bc ) 
  cut -f1,"$column"  sas/output_cl_st1_querem/cl_st1_querem_scores_only.tsv | tail +2 > a

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
        user=$( rg $file file_index.txt | cut -d' ' -f4 | sed 's/u://' )
        url=$( rg $file file_index.txt | cut -d' ' -f5 | sed 's/url://' )

      # REGARDLESS OF FACTOR -- FACTOR FILTERING OCCURS FURTHER DOWN:
      grep -m1 $file  sas/output_cl_st1_querem/cl_st1_querem_scores.tsv | tr -d '\r' | tr '\t' '\n' > scores # var values for this text, incl. 0
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

}

latexexamples () {
    
rm -f list

# enter how many examples to be picked for each pole:    
pickexamples=50

mkdir -p examples/latex/input
rm -f examples/latex/input/examples_*

sort -k2,2 var_index.txt | cut -f2 > kw_index.txt

head -1  sas/output_group3/group3_scores.tsv | tr -d '\r' | tr '\t' '\n' > vars

last=$( cut -d' ' -f1 examples/factors | tr -dc '[0-9\n]' | sort | uniq | sort -nr | head -1 )

for i in $(eval echo {1..$last});
#for i in {1..6}
#for i in 4
do
  column=$( echo " $i + 1 " | bc ) 
  cut -f1,"$column"  sas/output_group3/group3_scores_only.tsv | tail +2 > a

  for pole in pos neg
  do
    echo "--- latex examples "f"$i""$pole"" ---" 

    if [ "$pole" == pos ] ; then
       sort -nr -k2,2 a | grep -v '\-' | head -"$pickexamples" | nl -nrz > files
    else
       sort -n -k2,2 a | grep '\-' | head -"$pickexamples" | nl -nrz > files
    fi

    grep f"$i""$pole" examples/factors | sort -t' ' -k2,2 | cut -d' ' -f2- | sort > factor_words  # the words loading on this factor


    while read n file score
    do

        textid=$file
        #conversation=$( rg $file file_index.txt | cut -d' ' -f2 | sed 's/v://' )
        date=$( rg $file file_index.txt | cut -d' ' -f3 | sed 's/d://' )
        user=$( rg $file file_index.txt | cut -d' ' -f4 | sed 's/u://' )
        #url=$( rg $file file_index.txt | cut -d' ' -f5 | sed 's/url://' )
        #wordsloading=$( join vars_text_codes factor_words | wc -l | tr -dc '[0-9]' ) 
        #wordcount=$( rg $file sas/wcount.txt | cut -d' ' -f2 | tr -dc '[0-9]' )
        

      # REGARDLESS OF FACTOR -- FACTOR FILTERING OCCURS FURTHER DOWN:
      grep -m1 $file  sas/output_group3/group3_scores.tsv | tr -d '\r' | tr '\t' '\n' > scores # var values for this text, incl. 0
      paste vars scores | tr '\t' ' ' | grep '^v' | grep -v ' 0$' | cut -d' ' -f1 | sort  > vars_text # var labels for this text, ie not 0
      join vars_text var_index.txt | cut -d' ' -f2 | sort > vars_text_codes # words that occur in this text 
      
      # FILTERING THE WORDS OCCURRING IN THIS TEXT BY THE WORDS LOADING ON THIS FACTOR
      join vars_text_codes factor_words | cut -d' ' -f1 | sed 's;\(.*\);/ \1$/s/+(.*+) +(.*+)/~textbf{+1}/;' | tr '+' '\' > tex.sed

      if [ "$pole" == pos ] ; then
         block=exampleblock
      else
          block=alertblock
      fi

      echo "~begin{frame}{Examples: Dimension $i "$pole", score $score, \# $n}" > e
      echo "~footnotesize" >> e
      echo "~begin{$block}{text: $file, user: $user, $date}" | sed -e 's/_/\\_/g' -e 's/#/\\#/g' -e 's/%/\\%/g' -e 's/\$/\\$/g' -e 's/\&/\\&/g' -e 's/\&amp/\&/g' >> e
      sed -f tex.sed examples/base/"$file".txt | sed -e 's/\([a-zA-Z0-9_-]*\)_e/\\emoji{\1}/g' -e 's/_/-/g' -e 's/-e}/e}/g' -e 's/_/\\_/g' -e 's/#/\\#/g' -e 's/%/\\%/g' -e 's/\$/\\$/g' -e 's/\&/\\&/g' -e 's/\&amp/\&/g' -e 's/\&lt/\$<\$/g' -e 's/\&gt/\$>\$/g' | sed -f emoji.sed | cut -d' ' -f1 > b

      tr '\n' ' ' < b | tr -s ' ' | sed 's/\([a-zA-Z]\) \([.,;:!?]\)/\1\2/g' | fold -s >> e
      cat c >> e
      echo "~end{$block}"  >> e
      
      emojicount=$( grep -c 'emoji' tex.sed | tr -dc '0-9' )  # tex.sed only contains factor words that occurred in the text 
      
      if [ "$emojicount" -gt 0 ] ; then
         echo > c
         echo "Factor-loading emoji in the text:" >> c
         echo "~begin{itemize}" >> c
         grep 'textbf{\\emoji' b | sort | uniq | sed 's/^/~item /' >> c
         echo "~end{itemize}" >> c
         echo >> c
      else
          echo "" > c
      fi
            
      echo "~end{frame}"  >> e
      sed -f tex.sed e | tr '~' '\' > examples/latex/input/examples_f"$i"_"$pole"_"$n".tex
      
      echo "--- examples/latex/input/examples_f"$i"_"$pole"_"$n".tex ---" 
      
      echo "\\input{input/examples_f"$i"_"$pole"_"$n".tex}" >> list  # list of input .tex files 

    done < files 

  done

done

#rm -f vars factor_words scores vars_text vars_text_codes

}

treetagging
tokenstypes
toplemmas
sas
datamatrix
correlationmatrix

formats
#classify
#examples

#latexexamples
