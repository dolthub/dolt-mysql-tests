# Dolt MySQL Integration Tests

This repository houses a collection of tests from the official [MySQL Test Suite](https://dev.mysql.com/doc/refman/8.0/en/mysql-test-suite.html), along with a set of scripts in order to run the tests nightly against the latest commit of [Dolt](https://github.com/liquidata-inc/dolt). This is a subcollection of tests, as Dolt does not aim to be a complete drop-in replacement for MySQL. Rather, these tests are used as a general baseline for stability and correctness, along with an emulation of MySQL that is _good enough_ for the majority of expected workloads.

## Running Locally

Although not the primary objective, the scripts should allow you to run the tests locally against your own installation of Dolt. Refer to the [testharness README](https://github.com/liquidata-inc/dolt-mysql-tests/blob/master/testharness/README.md) for specific details on the individual scripts.

Requirements:
- [Go](https://golang.org/dl/) (1.12+)
- [Dolt](https://github.com/liquidata-inc/dolt)
- Git

Both Go and Dolt have installation scripts that are used by the testing machines, however they may be used to install the binaries for yourself as well. In the case of Dolt, the latest commit from master will be installed.

To run tests, the *mysqltest* binary is invoked through the [runtest](https://github.com/liquidata-inc/dolt-mysql-tests/blob/master/testharness/runtest.sh) script. The script handles the creation and destruction of a Dolt SQL server, along with iterating through all of the tests in the [suite](https://github.com/liquidata-inc/dolt-mysql-tests/tree/master/files/suite) directory. By default, the results are printed to the console, with logs and reject files written to a top-level *output* directory. However `DTENABLEFILEOUTPUT=true` will write the results to two files within the aforementioned *output* directory. In addition, if only a single test needs to be ran, the test may be passed as a parameter in the form of `./runtest.sh <suite_name> <test_name>` or `./runtest.sh <suite_name>/<test_name>`. Example: `./runtest.sh other/1st`.

If any errors are encountered specifying the *mysqltest* binary as the culprit, then it may be due to an incompatibility between the libraries that mysqltest expects and the ones installed (assuming a 64-bit Linux OS). The environment variable `DOLTTESTLINKER=true` may fix these issues, but if not then you can compile *mysqltest* from [source](https://github.com/mysql/mysql-server) and replace the binary locally.

### Parsing Output

If `DTENABLEFILEOUTPUT=true` is set, then two additional files will be present in the output folder named *results.txt* and *output.txt*. *results.txt* contains the overall result of each test, while *details.txt* contains more information on a particular test. To make the results a bit more readable, you can run `go run parseoutput.go`, which will read the output folder and generate a file *doltvals.json* in the *testharness* directory. This JSON file contains all of the data in the *output* directory, including the contents of the *reject* and *log* directories.
