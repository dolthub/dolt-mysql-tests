package main

import (
	"fmt"
	"io/ioutil"
	"os"
	"path/filepath"
	"testing"
)

func TestParseOutput(t *testing.T) {
	results := parseResultFile("testdata", "testversion")
	parseDetailsFile("testdata", results)
	dir, err := ioutil.TempDir("", "TestParseOutput")
	if err != nil {
		t.Fatal("Unexpected error", err)
	}
	outputFile := filepath.Join(dir, "doltvals.json")

	writeResultsFile(outputFile, results)
	assertFilesEqual(t, "testdata/doltvals.json", outputFile)
}

func assertFilesEqual(t *testing.T, expected, actual string) {
	expectedFile, err := os.Open(expected)
	if err != nil {
		t.Fatal("Unexpected error", err)
	}
	actualFile, err := os.Open(actual)
	if err != nil {
		t.Fatal("Unexpected error", err)
	}

	expectedContents, err := ioutil.ReadAll(expectedFile)
	if err != nil {
		t.Fatal("Unexpected error", err)
	}

	actualContents, err := ioutil.ReadAll(actualFile)
	if err != nil {
		t.Fatal("Unexpected error", err)
	}

	if len(expectedContents) != len(actualContents) {
		t.Fatal("Different lengths for files: ", expected, actual)
	}

	for i := range expected {
		if expectedContents[i] != actualContents[i] {
			t.Fatal(fmt.Sprintf("File contents differ at byte %d", i), expected, actual)
		}
	}
}