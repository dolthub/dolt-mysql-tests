#!/bin/bash

if [ -d lib/ ]; then
  cd ..
fi

FILESDIR="$PWD/files"
CREATEDTESTDOLTDIR="$PWD/files/.dolt"
function removeTempDolt() {
  if [ -n "$DOLTPID" ]; then
    kill "$DOLTPID" >/dev/null
  fi
  rm -rf "$CREATEDTESTDOLTDIR"
}
trap removeTempDolt EXIT

DOLTTESTRESULTOUT="/dev/tty"
DOLTTESTDETAILOUT="/dev/tty"
if [ "$DTENABLEFILEOUTPUT" = true ]; then
  DOLTTESTRESULTOUT="$PWD/output/results.txt"
  DOLTTESTDETAILOUT="$PWD/output/details.txt"
fi

if [ -d output/ ]; then
  rm -rf output
fi
mkdir output

MYSQLTEST="timeout -k 1m 5m $PWD/testharness/mysqltest"
if [ "$DOLTTESTLINKER" = true ]; then
  MYSQLTEST="timeout -k 1m 5m $PWD/testharness/lib/ld-linux-x86-64.so.2 --library-path $PWD/testharness/lib $PWD/testharness/mysqltest"
fi

ARG1="$1"
ARG2="$2"
if [ -n "$1" ] && [ -z "$2" ]; then
  FULLSUITENAME="$1"
  ARG1="${FULLSUITENAME%/*}"
  ARG2="${FULLSUITENAME#*/}"
fi

{ # Redirect all output contained in this block to files

function startDoltServer() {
  pushd $FILESDIR >/dev/null
  removeTempDolt
  dolt init >/dev/null
  jobs &>/dev/null
  dolt sql-server -H 127.0.0.1 -P 9091 -u root &
  NEWJOBSTARTED="$(jobs -n)"
  if [ -n "$NEWJOBSTARTED" ]; then
    DOLTPID=$!
  else
    DOLTPID=
  fi
  popd >/dev/null
}

function runTest() {
  startDoltServer
  SUITENAME="$1"
  TESTNAME="$2"
  if [ "$DTENABLEFILEOUTPUT" = true ]; then
    echo -n "$SUITENAME/$TESTNAME:"
  fi
  echo "Start:----- $SUITENAME/$TESTNAME" >&2
  if [ -f $PWD/r/$TESTNAME.result ]; then
    $MYSQLTEST -h 127.0.0.1 -P 9091 -u root -x $PWD/t/$TESTNAME.test -R $PWD/r/$TESTNAME.result
  else
    $MYSQLTEST -h 127.0.0.1 -P 9091 -u root -x $PWD/t/$TESTNAME.test
  fi
  if [ "$DTENABLEFILEOUTPUT" = true ]; then
    LASTLINEWRITTEN=`cat $DOLTTESTRESULTOUT | tail -n 1`
    if [ -n "$LASTLINEWRITTEN" ]; then
      STATUSLASTLINEWRITTEN="${LASTLINEWRITTEN#*:}"
      if [ -z "$STATUSLASTLINEWRITTEN" ]; then
        echo "not ok"
      fi
    fi
  fi
  echo "End:------- $SUITENAME/$TESTNAME" >&2
}

TESTCOUNTER=0
cd files/suite
for TOPLEVEL in */; do
  TOPLEVEL="${TOPLEVEL%/}"
  cd $TOPLEVEL
  for TEST in t/*.test; do
    TESTWITHT="${TEST%.*}"
    TESTWITHOUTT="${TESTWITHT:2}"
    if [ -n "$ARG1" ]; then
      if [ "$ARG1" == "$TOPLEVEL" ] && [ "$ARG2" == "$TESTWITHOUTT" ]; then
        runTest "$TOPLEVEL" "$TESTWITHOUTT"
      fi
    else
      runTest "$TOPLEVEL" "$TESTWITHOUTT"
    fi
    TESTCOUNTER=$((TESTCOUNTER+1))
    if [ $((TESTCOUNTER % 100)) -eq 0 ] && [ "$DTENABLEFILEOUTPUT" = true ]; then
      echo "`date -u`: Finished $TESTCOUNTER tests" >/dev/tty
    fi
  done

  for REJECT in *.reject; do
    if [ -f $REJECT ]; then
      if [ ! -d "../../../output/reject/$TOPLEVEL" ]; then
        mkdir -p "../../../output/reject/$TOPLEVEL/"
      fi
      mv $REJECT "../../../output/reject/$TOPLEVEL/$REJECT"
    fi
  done

  cd r
  for LOGFILE in *.log; do
    if [ -f $LOGFILE ]; then
      if [ ! -d "../../../../output/log/$TOPLEVEL" ]; then
        mkdir -p "../../../../output/log/$TOPLEVEL/"
      fi
      mv $LOGFILE "../../../../output/log/$TOPLEVEL/$LOGFILE"
    fi
  done
  cd ../..
done
cd ../..

} 1>$DOLTTESTRESULTOUT 2>$DOLTTESTDETAILOUT # Output redirection target files
