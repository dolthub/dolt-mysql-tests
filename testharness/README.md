# Files

## installdolt.sh

Clones the latest commit from the master branch of [Dolt](https://github.com/liquidata-inc/dolt) and installs it. After running, it leaves behind a **dolt** folder in the **testharness** directory (the git directory), as well as the file **currentdolt.txt** (commit hash), which is used by [setuprepo.sh](https://github.com/liquidata-inc/dolt-mysql-tests/tree/master/testharness#setupreposh) and also [parseoutput.go](https://github.com/liquidata-inc/dolt-mysql-tests/tree/master/testharness#parseoutputgo).

## installgo.sh

Installs [Go](https://golang.org/) version 1.12.9. This file should work for most Linux and MacOS distributions. It is possible for the script to not detect a current Go installation and install another, so it is recommended that Go is installed through the official channels.

## mysqltest

The MySQL test binary that was compiled under Ubuntu 19.04 64-bit. The accompanying [lib](https://github.com/liquidata-inc/dolt-mysql-tests/tree/master/testharness/lib) folder contains the libraries necessary to run this binary under different OS installations on our test machines. If any error is encountered surrounding this library, then it may be best to compile the binary under your own test environment: [MySQL Server Source](https://github.com/mysql/mysql-server).

## parseoutput.go

A Go project that reads the output of the generated **output** folder (along with **currentdolt.txt**) and outputs a JSON file named **doltvals.json**. This file is then used in our testing process to update [our results table](https://beta.dolthub.com/repositories/Liquidata/mysql-integration-tests) for tracking progress. It is required that **currentdolt.txt** exists in **testharness** before running, and for the purposes of local testing, you may create your own file with `echo -n "SOME_COMMIT_HASH" > currentdolt.txt`, replacing `SOME_COMMIT_HASH` with the relevant hash of [Dolt](https://github.com/liquidata-inc/dolt). It is not required to build this file before running, and thus may be ran with the command `go run parseoutput.go`.

## runtest.sh

The testing script that iterates through the contents of **files/suite**. When run without any additional parameters nor environment variables, it locates every **.test** file in **files/suite/SUITE_NAME/t** and matches that with the equivalent-named **.result** file in **files/suite/SUITE_NAME/r**. If the **.result** file does not exist, then the test runs with the assumption that no output will be observed, and thus will error if any output is generated (even success messages). Before running, the script will remove all contents of the **output** folder if it exists, or create the folder if it doesn't. It then moves all generated **.reject** and **.log** files to the **output** folder. The results of the tests are output to the screen. Additionally, a **.dolt** directory is created in **files** that is used for the Dolt SQL server.

If only a single test is desired, then you may pass in that test name in the form of `./runtest.sh SUITE_NAME/TEST_NAME` or `./runtest.sh SUITE_NAME TEST_NAME`, where the `SUITE_NAME` is the highest-level folder name under **files/suite** for a test, and the `TEST_NAME` is the file name of the test sans **.test** extension.

If the environment variable `DTENABLEFILEOUTPUT` is set to `true`, then the script will the screen output to **results.txt** and **details.txt** files under the **output** folder. This variable must be set if you want to parse the **output** folder. **results.txt** contains the test ID (`SUITE_NAME/TEST_NAME`) followed by the overall test result (`ok`, `not ok`, or `skipped`) in the form of `SUITE_NAME/TEST_NAME:RESULT`. If only one test was ran, then this file will contain only that result. **details.txt** contains everything else that was displayed on screen. For each test, they are surrounded by a start tag of the form `Start:----- SUITE_NAME/TEST_NAME`, and an end tag of the form `End:------- SUITE_NAME/TEST_NAME`.

If the environment variable `DOLTTESTLINKER` is set to `true`, then the script will use the linker and libraries in **testharness/lib** to run the [mysqltest](https://github.com/liquidata-inc/dolt-mysql-tests/tree/master/testharness#mysqltest) binary. This is a potential alternative to compiling your own [mysqltest](https://github.com/liquidata-inc/dolt-mysql-tests/tree/master/testharness#mysqltest) binary. Using this binary does guarantee compatibility with the test machines, as a different test binary may yield different results for some tests, although this has not been attempted nor observed.

## setuprepo.sh

Turns **testharness** into a [Dolt](https://github.com/liquidata-inc/dolt) directory and clones the latest results from the [Liquidata repository](https://beta.dolthub.com/repositories/Liquidata/mysql-integration-tests) into it. It then grabs the latest commit from the repository itself and writes it to **previousdolt.txt**. **currentdolt.txt** and **previousdolt.txt** are then compared for equivalence, and exits with code 3 if they are. This is used by our Jenkins script to skip redundant runs. This file is only intended to be ran from the test machines.

## updaterepo.sh

Runs the [output parser](https://github.com/liquidata-inc/dolt-mysql-tests/tree/master/testharness#parseoutputgo) and uses the created **doltvals.json** to update the [Dolt](https://github.com/liquidata-inc/dolt) repository created using the [setuprepo.sh](https://github.com/liquidata-inc/dolt-mysql-tests/tree/master/testharness#setupreposh) script. It then pushes the result upstream to the repository, and deletes the **doltvals.json** file. This file is only intended to be ran from the test machines.
