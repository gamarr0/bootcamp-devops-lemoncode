#!/bin/bash
if [ $# -ne 2 ]; then
  echo "> Se necesitan únicamente dos parámetros para ejecutar este script"
  exit 1
fi

readonly URL=$1
readonly WORD=$2

curl -s $URL -o fichero
OCURRENCES=(`grep -o -n $WORD fichero | cut -d':' -f 1`)
NUM_OCURRENCES=${#OCURRENCES[@]}

if [ $NUM_OCURRENCES -eq 0 ]; then
  echo "> No se ha encontrado la palabra \"$WORD\""
elif [ $NUM_OCURRENCES -eq 1 ]; then
  echo "> La palabra \"$WORD\" aparece 1 vez"
  echo "> Aparece únicamente en la línea ${OCURRENCES[0]}"
else
  echo "> La palabra \"$WORD\" aparece $NUM_OCURRENCES veces"
  echo "> Aparece por primera vez en la línea ${OCURRENCES[0]}"
fi
