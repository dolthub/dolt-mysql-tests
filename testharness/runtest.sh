#!/bin/bash

if [ -d lib/ ]; then
  cd ..
fi

FILESDIR="$PWD/files"
CREATEDTESTDOLTDIR="$PWD/files/.dolt"

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

# For local debugging, a much shorter timeout is more appropriate.
#MYSQLTEST="timeout -k 5s 10s mysqltest --max-connect-retries=2"
MYSQLTEST="timeout -k 1m 5m $PWD/testharness/mysqltest"
if [ "$DOLTTESTLINKER" = true ]; then
  MYSQLTEST="timeout -k 1m 5m $PWD/testharness/lib/ld-linux-x86-64.so.2 --library-path $PWD/testharness/lib $PWD/testharness/mysqltest"
fi

suiteName="$1"
testName="$2"
# Alternate test name declaration: suiteName/testName
if [ -z "$testName"] && [[ $suiteName == *"/"* ]]; then
    fullName="$suiteName"
    suiteName="${fullName%/*}"
    testName="${fullName#*/}"
fi

{ # Redirect all output contained in this block to files

doltPid="" # global, used for cleanup
function removeTempDolt() {
  if [ -n "$doltPid" ]; then
    kill "$doltPid" >&2
  fi
  rm -rf "$CREATEDTESTDOLTDIR" >&2
}
trap removeTempDolt EXIT

    
# Runs all the tests in a suite, which must be CWD.
function runSuite() {
    local suiteName="$1"
    for test in t/*.test; do
        testWithoutSuffix="${test%.*}"
        testName="${testWithoutSuffix##*/}"
        runTest "$suiteName" "$testName"
        testCounter=$((testCounter+1))
        if [ $((testCounter % 100)) -eq 0 ] && [ "$DTENABLEFILEOUTPUT" = true ]; then
            echo "`date -u`: Finished $testCounter tests" >/dev/tty
        fi
    done
}

function startDoltServer() {
    pushd $FILESDIR >/dev/null
    removeTempDolt
    dolt init --name mysqltest --email mysqltests@test.com >&2
    jobs &>/dev/null
    dolt sql-server -H 127.0.0.1 -P 9091 -u root &
    newJobStarted="$(jobs -n)"
    if [ -n "$newJobStarted" ]; then
        doltPid=$!
    else
        doltPid=
    fi
    popd >/dev/null
}

# Runs a single test. Expects CWD to be the test suite directory.
function runTest() {
    startDoltServer
    local suiteName="$1"
    local testName="$2"
    if [ "$DTENABLEFILEOUTPUT" = true ]; then
        echo -n "$suiteName/$testName:"
    fi

    echo "Start:----- $suiteName/$testName" >&2

    echo -n "StartTime:" >&2
    date "+%s-%N" >&2
    
    if [ -f $PWD/r/$testName.result ]; then
        $MYSQLTEST -h 127.0.0.1 -P 9091 -u root -x $PWD/t/$testName.test -R $PWD/r/$testName.result
    else
        $MYSQLTEST -h 127.0.0.1 -P 9091 -u root -x $PWD/t/$testName.test
    fi
    
    if [ "$DTENABLEFILEOUTPUT" = true ]; then
        # For tests that timed out without writing a result, write "not ok"
        lastLineWritten=`cat $DOLTTESTRESULTOUT | tail -n 1`
        if [ -n "$lastLineWritten" ]; then
            statusLastLineWritten="${lastLineWritten#*:}"
            if [ -z "$statusLastLineWritten" ]; then
                echo "not ok"
            fi
        fi
    fi
    
    echo -n "EndTime:" >&2
    date "+%s-%N" >&2
    echo "End:------- $suiteName/$testName" >&2

    cleanupRejects "$suiteName"
    cleanupLogs "$suiteName"
}

# Cleans up .reject files in the current directory, moving them to the output/reject directory
function cleanupRejects() {
    local suite="$1"
    for reject in *.reject; do
        if [ -f $reject ]; then
            if [ ! -d "../../../output/reject/$suite" ]; then
                mkdir -p "../../../output/reject/$suite/"
            fi
            mv $reject "../../../output/reject/$suite/$reject"
        fi
    done
}

# Cleans up any .log files in $PWD/r by moving them to the output/log directory 
function cleanupLogs() {
    local suite="$1"
    cd r
    for logfile in *.log; do
        if [ -f $logfile ]; then
            if [ ! -d "../../../../output/log/$suite" ]; then
                mkdir -p "../../../../output/log/$suite/"
            fi
            mv $logfile "../../../../output/log/$suite/$logfile"
        fi
    done
    cd ..
}

testCounter=0
cd files/suite

if [ -n "$suiteName" ] && [ -d "$suiteName" ]; then
    echo "Running suite $suiteName" > /dev/tty
    cd $suiteName
    if [ -n "$testName" ]; then
        if [ -f "t/$testName.test" ]; then
            echo "Running single test $testName" > /dev/tty
            runTest "$suiteName" "$testName"
        else
            echo "No $testName.test found, exiting" > /dev/tty
            exit
        fi
    else
        echo "Running entire suite $suiteName" > /dev/tty
        runSuite "$suitName"
    fi
else
    echo "Running all suites" > /dev/tty
    for suite in */; do
        suite="${suite%/}"
        cd $suite
        runSuite "$suite"
        cd ..
    done
fi

} 1>$DOLTTESTRESULTOUT 2>$DOLTTESTDETAILOUT # Output redirection target files
