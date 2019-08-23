#!/bin/bash

function onExit() {
  rm doltvals.json
}
trap onExit EXIT

go run parseoutput.go
if [ $? -ne 0 ]; then
  echo "`date -u`: 'go run parseoutput.go' failed" >> ../FAILED.txt
  exit 1
fi

dolt table import -u results doltvals.json
dolt add .
dolt commit -m "Scheduled testing"
dolt push origin master
