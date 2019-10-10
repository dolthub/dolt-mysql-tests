package main

import (
	"bufio"
	"encoding/json"
	"io/ioutil"
	"log"
	"os"
	"path/filepath"
	"sort"
	"strconv"
	"strings"
	"time"
)

type Results map[string]*TestResult
type Result string
const (
	Result_Unknown Result = ""
	Result_Passed Result = "ok"
	Result_Failed Result = "not ok"
	Result_Skipped Result = "skipped"
)

const startMarker = "Start:----- "
const endMarker = "End:------- "
const startTimeMarker = "StartTime:"

const endTimeMarker = "EndTime:"

type State struct {
	TestResult *TestResult
	StringBuilder strings.Builder
	FirstTimestamp time.Time
	LastTimestamp time.Time
}

type TestResult struct {
	Name           string `json:"test_name"`
	Result         Result `json:"result"`
	CommitHash     string `json:"commit_hash"`
	ElapsedSeconds int64  `json:"elapsed_seconds"`
	Info           string `json:"details,omitempty"`
	Reject         string `json:"reject,omitempty"`
	Log            string `json:"log,omitempty"`
}

type TestResultArray struct {
	Rows []*TestResult `json:"rows"`
}

func main() {
	globalCommitHash, err := readFile("currentdolt.txt")
	if err != nil {
		log.Fatal(err)
	}

	results := parseResultFile("../output", globalCommitHash)
	parseDetailsFile("../output", results)
	writeResultsFile("doltvals.json", results)
}

func parseResultFile(outputDir, commitHash string) Results {
	resultFile := filepath.Join(outputDir, "results.txt")
	resultFileLines, err := readFileToLines(resultFile)
	if err != nil {
		log.Fatal(err)
	}

	results := Results(make(map[string]*TestResult))
	for _, resultLine := range resultFileLines {
		resultSplit := strings.Split(resultLine, ":")
		testResult := &TestResult{
			Name:       resultSplit[0],
			CommitHash: commitHash,
		}
		switch Result(resultSplit[1]) {
		case Result_Passed:
			testResult.Result = Result_Passed
		case Result_Failed:
			testResult.Result = Result_Failed
		case Result_Skipped:
			testResult.Result = Result_Skipped
		default:
			testResult.Result = Result_Unknown
		}
		results[testResult.Name] = testResult
	}

	return results
}

func parseDetailsFile(outputDir string, results map[string]*TestResult) {
	detailsFile := filepath.Join(outputDir, "details.txt")
	detailFileLines, err := readFileToLines(detailsFile)
	if err != nil {
		log.Fatal(err)
	}

	state := &State{}
	state.reset()

	for _, detailLine := range detailFileLines {
		if state.TestResult == nil {
			if strings.HasPrefix(detailLine, startMarker) {
				testName := detailLine[len(startMarker):]
				var ok bool
				if state.TestResult, ok = results[testName]; !ok {
					log.Fatalf("Unrecognized test name %v on line %v", testName, detailLine)
				}
			}
			continue
		}

		if strings.HasPrefix(detailLine, endMarker+state.TestResult.Name) {
			state.TestResult.Info = strings.TrimSpace(state.StringBuilder.String())
			state.TestResult.ElapsedSeconds = int64(state.LastTimestamp.Sub(state.FirstTimestamp).Seconds())


			rejectFileName := filepath.Join(outputDir, "reject", state.TestResult.Name + ".reject")
			if fileExists(rejectFileName) {
				state.TestResult.Reject, err = readFile(rejectFileName)
				if err != nil {
					log.Fatal(err)
				}
			}

			logFileName := filepath.Join(outputDir, "log", state.TestResult.Name + ".log")
			if fileExists(logFileName) {
				state.TestResult.Log, err = readFile(logFileName)
				if err != nil {
					log.Fatal(err)
				}
			}
			state.reset()
			continue
		}

		if strings.HasPrefix(detailLine, startTimeMarker) {
			timeString := detailLine[len(startTimeMarker):]
			timestamp := parseTimestamp(timeString)
			state.FirstTimestamp = timestamp
		} else if strings.HasPrefix(detailLine, endTimeMarker) {
			timeString := detailLine[len(endTimeMarker):]
			timestamp := parseTimestamp(timeString)
			state.LastTimestamp = timestamp
		} else if detailLine != "" &&
				!strings.Contains(detailLine, `msg="NewConnection: client `) &&
				!strings.Contains(detailLine, `msg="ConnectionClosed: client `) &&
				!strings.Contains(detailLine, `msg="audit trail"`) {
			state.StringBuilder.WriteString(detailLine)
			state.StringBuilder.WriteRune('\n')
		}
	}
}

func parseTimestamp(timeString string) time.Time {
	// These timestamps are generated by `date "+%s-%N"`
	secondsAndNanos := strings.Split(timeString, "-")
	seconds, err := strconv.ParseInt(secondsAndNanos[0], 10, 64)
	if err != nil {
		log.Fatalf("Couldn't parse int %v: %v", secondsAndNanos[0], err)
	}
	nanos, err := strconv.ParseInt(secondsAndNanos[1], 10, 64)
	if err != nil {
		log.Fatalf("Couldn't parse int %v: %v", secondsAndNanos[1], err)
	}
	timestamp := time.Unix(seconds, nanos)
	return timestamp
}

func writeResultsFile(outputFile string, results map[string]*TestResult) {
	var testNames []string
	for testName := range results {
		testNames = append(testNames, testName)
	}
	sort.Strings(testNames)

	resultsArray := &TestResultArray{make([]*TestResult, len(results))}
	for i, testName := range testNames {
		resultsArray.Rows[i] = results[testName]
	}
	resultsJSONBytes, err := json.Marshal(resultsArray)
	if err != nil {
		log.Fatal(err)
	}
	err = ioutil.WriteFile(outputFile, resultsJSONBytes, 0644)
	if err != nil {
		log.Fatal(err)
	}
}

func (s *State) reset() {
	s.TestResult = nil
	s.StringBuilder.Reset()
	s.FirstTimestamp = time.Time{}
	s.LastTimestamp = time.Time{}
}

func readFileToLines(path string) ([]string, error) {
	file, err := os.Open(path)
	if err != nil {
		return nil, err
	}
	defer file.Close()

	var lines []string
	scanner := bufio.NewScanner(file)
	scanner.Buffer(make([]byte, 0, 64*1024), 10*1024*1024)
	for scanner.Scan() {
		lines = append(lines, scanner.Text())
	}
	return lines, scanner.Err()
}

func readFile(path string) (string, error) {
	fileLines, err := readFileToLines(path)
	if err != nil {
		return "", err
	}
	return strings.Join(fileLines, "\n"), nil
}

func fileExists(path string) bool {
	fileInfo, err := os.Stat(path)
	return !os.IsNotExist(err) && !fileInfo.IsDir()
}
