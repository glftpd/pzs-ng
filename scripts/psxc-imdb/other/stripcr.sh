#!/bin/bash

if [ $# -ne 1 ]; then
 echo "Strip CR - removes <cr> from files."
 echo "usage: $0 <filename>"
 exit 0
fi
tmp="`cat $1 | tr -d ''`"
echo "$tmp" >$1


