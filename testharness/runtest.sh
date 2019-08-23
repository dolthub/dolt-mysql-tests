 #!/bin/bash

if [ -d lib/ ]; then
  cd ..
fi

function onExit() {
  kill $DOLTPID
}
trap onExit EXIT

DOLTTESTRESULTOUT="/dev/tty"
DOLTTESTDETAILOUT="/dev/tty"
if [ "$DTENABLEFILEOUTPUT" = true ]; then
  DOLTTESTRESULTOUT="output/results.txt"
  DOLTTESTDETAILOUT="output/details.txt"
  if [ -d output/ ]; then
    rm -rf output
  fi
  mkdir output
fi

MYSQLTEST="$PWD/testharness/mysqltest"
if [ "$DOLTTESTLINKER" = true ]; then
  MYSQLTEST="$PWD/testharness/lib/ld-linux-x86-64.so.2 --library-path $PWD/testharness/lib $PWD/testharness/mysqltest"
fi

ARG1="$1"
ARG2="$2"
if [ -n "$1" ] && [ -z "$2" ]; then
  FULLSUITENAME="$1"
  ARG1="${FULLSUITENAME%/*}"
  ARG2="${FULLSUITENAME#*/}"
fi

{ # Redirect all output contained in this block to files

cd files
if [ ! -d .dolt/ ]; then
  dolt init >/dev/null
fi
jobs &>/dev/null
dolt sql-server -H 127.0.0.1 -P 9091 -u root &
NEWJOBSTARTED="$(jobs -n)"
if [ -n "$NEWJOBSTARTED" ]; then
  DOLTPID=$!
else
  DOLTPID=
fi
cd ..

function runTest() {
  SUITENAME="$1"
  TESTNAME="$2"
  echo -n "$SUITENAME/$TESTNAME:"
  echo "Start:----- $SUITENAME/$TESTNAME" >&2
  if [ -f $PWD/r/$TESTNAME.result ]; then
    $MYSQLTEST -h 127.0.0.1 -P 9091 -u root -x $PWD/t/$TESTNAME.test -R $PWD/r/$TESTNAME.result
  else
    $MYSQLTEST -h 127.0.0.1 -P 9091 -u root -x $PWD/t/$TESTNAME.test
  fi
  echo "End:------- $SUITENAME/$TESTNAME" >&2
}

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
  done

  for REJECT in *.reject; do
    if [ -f $REJECT ]; then
      if [ ! -d "../../../output/reject/$TOPLEVEL" ]; then
        mkdir -p "../../../output/reject/$TOPLEVEL/"
      fi
      mv $REJECT "../../../output/reject/$TOPLEVEL/$REJECT"
    fi
  done
  cd ..
done
cd ../..

} 1>$DOLTTESTRESULTOUT 2>$DOLTTESTDETAILOUT # Output redirection target files
