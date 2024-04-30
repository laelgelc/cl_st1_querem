#!/bin/bash

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
