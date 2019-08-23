#!/bin/bash

if [ ! -f ~/.dolt/config_global.json ]; then
  echo "`date -u`: global dolt config has not been created" >> ../FAILEDPARSE.txt
  exit 1
fi

if [ ! -d .dolt/ ]; then
  dolt clone Liquidata/mysql-integration-tests
  if [ $? -ne 0 ]; then
    echo "`date -u`: 'dolt clone Liquidata/mysql-integration-tests' failed" >> ../FAILEDPARSE.txt
    exit 1
  fi
  mv mysql-integration-tests/.dolt ./.dolt
  rm -rf mysql-integration-tests
fi

dolt reset --hard
dolt pull

dolt sql -q "select commit_hash from results where test_name='other/1st'" | tail -n+4 | head -n1 | tr -d '| \n' > previousdolt.txt
cmp -s currentdolt.txt previousdolt.txt
if [ $? -eq 0 ]; then
  echo "No new commits to dolt, no need to continue"
  exit 3
fi
