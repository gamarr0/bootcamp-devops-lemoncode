#!/bin/bash
mkdir -p foo/{dummy,empty}
echo ${1:-'Que me gusta la bash!!!!'} | tee foo/{dummy/file1,empty/file2}.txt >/dev/null
