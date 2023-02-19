# Bootcamp Devops Continuo - Módulo 1 - Linux

## Soluciones a ejercicios

### Ejercicios CLI

#### 1. Crear jerarquía de ficheros y directorios

```bash
mkdir -p foo/{dummy,empty}
echo 'Me encanta la bash!!' >foo/dummy/file1.txt
touch foo/dummy/file2.txt
```

#### 2. Mover contenido de file1.txt a file2.txt y mover file2.txt a la carpeta empty

```bash
cat foo/dummy/file1.txt >>foo/dummy/file2.txt
mv foo/{dummy/file2.txt,empty/}
```

#### 3. Script bash que agrupe los anteriores ejercicios y obtenga el contenido del fichero por parámetro

Como a priori sabemos que los dos ficheros acabarán con el mismo contenido, usamos el comando `tee` para crear ambos ficheros directamente con dicho contenido.

```bash
#!/bin/bash
mkdir -p foo/{dummy,empty}
echo ${1:-'Que me gusta la bash!!!!'} | tee foo/{dummy/file1,empty/file2}.txt >/dev/null
```
*ejercicio3.sh*

#### 4 . Script bash que descargue el contenido de una web y busque una palabra en él

Para obtener el número de ocurrencias aprovechamos el flag `-o` que hace que `grep` devuelva una línea por cada ocurrencia, ya que si no las múltiples ocurrencias en una línea no se tendrían en cuenta.

Para obtener la línea de la primera ocurrencia usamos el flag `-n` para que grep muestre el número de línea y `-m 1` para procesar solo una ocurrencia.

```bash
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
```
*ejercicio4.sh*

#### 5. Modificar el script anterior para obtener la URL por parámetro y verificar la llamada al script

Como mejora con respecto al ejercicio anterior, usamos un array para guardar la línea de cada ocurrencia, de modo que con solo ejecutar `grep` una vez podemos contar las ocurrencias y saber la línea de la primera ocurrencia usando expansión de parámetros.

```bash
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
```
*ejercicio5.sh*
