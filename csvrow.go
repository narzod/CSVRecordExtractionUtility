package main

import (
  "os"
  "flag"
  "fmt"
  "os/exec"
  "regexp"
  "strings"
  "path/filepath"
)

func isURL(input string) bool {
  return strings.HasPrefix(input, "http://") ||
    strings.HasPrefix(input, "https://")
}

func getFileContent(fileLocator string) (string, error) {
  var data []byte
  var err error

  // Determine the appropriate rclone command
  var cmd *exec.Cmd
  if isURL(fileLocator) {
    cmd = exec.Command("rclone", "copyurl", fileLocator, "--stdout")
  } else {
    cmd = exec.Command("rclone", "cat", fileLocator)
  }

  // fmt.Fprintf(os.Stderr, "Running command:", cmd)
  data, err = cmd.Output()

  // Handle errors after fetching data
  if err != nil {
    return "", fmt.Errorf("Unable to fetch CSV content: %w", err)
  }

  // Normalize line endings and trim whitespace
  content := strings.ReplaceAll(string(data), "\r\n", "\n")
  content = strings.TrimSpace(content)

  if isURL(content) {
    return getFileContent(content)
  } else {
    return content, nil
  }
}

func getRecordByKey(lines []string, searchKey string) (string, bool) {
  pattern := "^" + searchKey + "," // Build pattern with searchKey
  regex := regexp.MustCompile(pattern)
  for _, line := range lines {
    if regex.MatchString(line) {
      return line, true
    }
  }
  return "", false
}

func main() {
  var separator string
  var verbose bool

  // Parse flags using the flag package
  flag.StringVar(&separator, "s", "=", "Separator between key and value")
  flag.BoolVar(&verbose, "v", false, "Print verbose output")

  // Custom usage function
  flag.Usage = func() {
      programName := filepath.Base(os.Args[0])
      fmt.Fprintf(os.Stderr, "Parses CSV data and outputs matching row as key-value pairs.\n\n")
      fmt.Fprintf(os.Stderr, "Usage: %s [options] <search_key> <file_locator>\n\n", programName)
      fmt.Fprintf(os.Stderr, "Arguments:\n")
      fmt.Fprintf(os.Stderr, "  <search_key>\n")
      fmt.Fprintf(os.Stderr, "         Value matching the first field in the target row\n")
      fmt.Fprintf(os.Stderr, "  <file_locator>\n")
      fmt.Fprintf(os.Stderr, "         URL or file corresponding to CSV data containing\n")
      fmt.Fprintf(os.Stderr, "         either actual CSV data or URL to data\n\n")
      fmt.Fprintf(os.Stderr, "Options:\n")
      flag.PrintDefaults()
      fmt.Fprintf(os.Stderr, "\n")
  }

  flag.Parse()

  remainingArgs := flag.Args()

  if len(remainingArgs) < 2 {
    flag.Usage()
    return
  }

  searchKey := remainingArgs[0]
  fileLocator := remainingArgs[1]

  // Fetch CSV content
  csvContent, err := getFileContent(fileLocator)
  if err != nil {
    fmt.Fprintf(os.Stderr, "Error:", err)
    return
  }

  if verbose {
    fmt.Fprintf(os.Stderr, "Fetched CSV content:\n")
    fmt.Fprintf(os.Stderr, csvContent)
  }

  // Process CSV content
  lines := strings.Split(csvContent, "\n")
  headerLine := lines[0]
  recordLine, found := getRecordByKey(lines[1:], searchKey)

  if found {
    headers := strings.Split(headerLine, ",")
    values := strings.Split(recordLine, ",")

    for i, header := range headers {
      if strings.ToUpper(header) == header { // Disclude lowercase and mixed case
        if i < len(values) { // Ensure index is within values bounds
          fmt.Printf("%s%s%s\n", header, separator, values[i])
        } else {
          fmt.Printf("%s%s\n", header, separator)
          if verbose {
            fmt.Fprintf(os.Stderr, "Warning: %s has no corresponding value.\n", header)
          }
        }
      }
    }

  } else if verbose {
    fmt.Fprintf(os.Stderr, "Pattern not found.")
  }
}

