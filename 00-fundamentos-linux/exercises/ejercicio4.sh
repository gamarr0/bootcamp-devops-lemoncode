#!/bin/bash
readonly URL='https://lemoncode.net/'
readonly WORD=$1

curl -s $URL -o fichero
OCURRENCES=`grep -o $WORD fichero | wc -l | tr -d ' '`
if [ $OCURRENCES -eq 0 ]; then
  echo "> No se ha encontrado la palabra \"$WORD\""
else
  FIRST_OCURRENCE=`grep -n -m 1 $WORD fichero | cut -d':' -f 1`
  echo "> La palabra \"$WORD\" aparece $OCURRENCES veces"
  echo "> Aparece por primera vez en la línea $FIRST_OCURRENCE"
fi
