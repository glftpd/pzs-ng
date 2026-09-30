#!/bin/bash

for file in * ; do
 if [ ! -e "$file" ] ; then
  echo "Removing $file..."
  rm -f "$file"
 fi
 if [ -d "$file" ] && [ ! -L "$file" ]; then
   cd "$file" || continue
   for underfile in * ; do
     if [ ! -e "$underfile" ] ; then
       echo "Removing $underfile..."
       rm -f "$underfile"
     fi
   done
   cd ..
 fi
done

