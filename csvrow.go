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

var usage = `csv2kvp - extracts key-value data from CSVs

    Usage: csv2kvp [options] <row_selector> <file_locator>

    Arguments:
      <row_selector>
             Value from first field in target row
      <file_locator>
             Local or remote path to file containing CSV data
             or URL pointing to CSV data

    Options:
      -s string
            Separator between key and value (default "=")
      -v    Enable verbose output

    Note:
      The <file_locator> argument supports rclone remotes as
      paths to CSV data or URLs to CSV data.  However, note 
      that URLs cannot point to another nested URL.
`

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

  flag.StringVar(&separator, "s", "=", "")
  flag.BoolVar(&verbose, "v", false, "")
  flag.Usage = func() {
    programName := filepath.Base(os.Args[0])
    usage = strings.ReplaceAll(usage, "csv2kvp", programName)
    usage = strings.ReplaceAll(usage, "\n    ", "\n")
    fmt.Fprintf(os.Stderr, "%s\n", usage)
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
