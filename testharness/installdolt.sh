#!/bin/bash

if [ ! -d dolt ]; then
  git clone https://github.com/liquidata-inc/dolt.git
  cd dolt
  git submodule init
  cd ..
fi

cd dolt
git reset --hard
git pull
git submodule update

git log -1 --format="%H" | tr -d '\n' > ../currentdolt.txt

cd go/cmd/dolt
go install .
if [ $? -ne 0 ]; then
  echo "`date -u`: 'go install .' failed" >> ../../../../../FAILED.txt
  exit 1
fi

cd ../../../..
