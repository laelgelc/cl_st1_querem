#!/bin/bash

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
