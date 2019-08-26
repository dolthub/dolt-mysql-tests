package main

import (
	"bufio"
	"encoding/json"
	"io/ioutil"
	"log"
	"os"
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
	resultFileLines, err := ReadFileToLines("../output/results.txt")
	if err != nil {
		log.Fatal(err)
	}
	detailFileLines, err := ReadFileToLines("../output/details.txt")
	if err != nil {
		log.Fatal(err)
	}
	globalCommitHash, err := ReadFile("currentdolt.txt")
	if err != nil {
		log.Fatal(err)
	}
	results := Results(make(map[string]*TestResult))
	for _, resultLine := range resultFileLines {
		resultSplit := strings.Split(resultLine, ":")
		testResult := &TestResult{
			Name: resultSplit[0],
			CommitHash: globalCommitHash,
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
	state := &State{}
	state.Reset()
	for _, detailLine := range detailFileLines {
		if state.TestResult == nil {
			if strings.HasPrefix(detailLine, "Start:----- ") {
				ok := false
				if state.TestResult, ok = results[detailLine[12:]]; !ok {
					log.Fatal("Invalid output start line: " + detailLine)
				}
			}
			continue
		}
		if strings.HasPrefix(detailLine, "End:------- " + state.TestResult.Name) {
			state.TestResult.Info = strings.TrimSpace(state.StringBuilder.String())
			state.TestResult.ElapsedSeconds = int64((time.Nanosecond * state.LastTimestamp.Sub(state.FirstTimestamp)) / time.Second)
			rejectFileName := "../output/reject/" + state.TestResult.Name + ".reject"
			if FileExists(rejectFileName) {
				state.TestResult.Reject, err = ReadFile(rejectFileName)
				if err != nil {
					log.Fatal(err)
				}
			}
			logFileName := "../output/log/" + state.TestResult.Name + ".log"
			if FileExists(logFileName) {
				state.TestResult.Log, err = ReadFile(logFileName)
				if err != nil {
					log.Fatal(err)
				}
			}
			state.Reset()
			continue
		}
		if strings.HasPrefix(detailLine, `time="`) {
			subDetailLine := detailLine[6:]
			timeOnly := subDetailLine[:strings.Index(subDetailLine, `"`)]
			parsedTime, err := time.Parse(time.RFC3339, timeOnly)
			if err != nil {
				log.Fatalf("Error parsing time: %v", err)
			}
			if state.FirstTimestamp.After(parsedTime) {
				state.FirstTimestamp = parsedTime
			}
			if state.LastTimestamp.Before(parsedTime) {
				state.LastTimestamp = parsedTime
			}
		}
		if detailLine != "" &&
			!strings.Contains(detailLine, `msg="NewConnection: client `) &&
			!strings.Contains(detailLine, `msg="ConnectionClosed: client `) &&
			!strings.Contains(detailLine, `msg="audit trail"`) {
			state.StringBuilder.WriteString(detailLine)
			state.StringBuilder.WriteRune('\n')
		}
	}

	resultsArray := &TestResultArray{make([]*TestResult, len(results))}
	resultsIndex := 0
	for _, result := range results {
		resultsArray.Rows[resultsIndex] = result
		resultsIndex++
	}
	resultsJSONBytes, err := json.Marshal(resultsArray)
	if err != nil {
		log.Fatal(err)
	}
	err = ioutil.WriteFile("doltvals.json", resultsJSONBytes, 0644)
	if err != nil {
		log.Fatal(err)
	}
}

// Removes all TestResults that returned false from filterFunc, returns a new Results struct
func (r Results) Filter(filterFunc func(result *TestResult) bool) Results {
	filteredResults := Results(make(map[string]*TestResult))
	for key, result := range r {
		if filterFunc(result) {
			filteredResults[key] = result
		}
	}
	return filteredResults
}

func (s *State) Reset() {
	s.TestResult = nil
	s.StringBuilder.Reset()
	s.FirstTimestamp = time.Unix(1<<63-62135596801, 999999999)
	s.LastTimestamp = time.Time{}
}

func ReadFileToLines(path string) ([]string, error) {
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

func ReadFile(path string) (string, error) {
	fileLines, err := ReadFileToLines(path)
	if err != nil {
		return "", err
	}
	return strings.Join(fileLines, "\n"), nil
}

func FileExists(path string) bool {
	fileInfo, err := os.Stat(path)
	return !os.IsNotExist(err) && !fileInfo.IsDir()
}