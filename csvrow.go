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

var usage = `[progName] - extracts key-value data from CSVs

Usage: [progName] [options] <row_selector> <file_locator>

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
  paths to CSV data. File may contain URL to CSV data,
  however, cannot point to another nested URL.
`

// ------------------------------------------------------------------------

func isURL(input string) bool {
  return strings.HasPrefix(input, "http://") ||
    strings.HasPrefix(input, "https://")
}

// ------------------------------------------------------------------------

func getFileContent(fileLocator string) (string, error) {
    // Define a closure for the recursive logic to prevent infinite loop
    var fetchContent func(fileLocator string, depth int) (string, error)
    
    fetchContent = func(fileLocator string, depth int) (string, error) {
        if depth > 2 { // Prevent infinite recursion
            return "", fmt.Errorf("recursion limit reached")
        }

        // Determine the appropriate rclone command
        var cmd *exec.Cmd
        if isURL(fileLocator) {
            cmd = exec.Command("rclone", "copyurl", fileLocator, "--stdout")
        } else {
            cmd = exec.Command("rclone", "cat", fileLocator)
        }

        data, err := cmd.Output()

        // Handle errors after fetching data
        if err != nil {
            return "", fmt.Errorf("unable to fetch content: %w", err)
        }

        // Normalize line endings and trim whitespace
        content := strings.ReplaceAll(string(data), "\r\n", "\n")
        content = strings.TrimSpace(content)

        if isURL(content) {
            return fetchContent(content, depth + 1)
        } else {
            return content, nil
        }
    }
    
    // Call the closure with initial depth 0
    return fetchContent(fileLocator, 0)
}

// ------------------------------------------------------------------------

func getRecordByKey(lines []string, rowSelector string) (string, bool) {
  pattern := "^" + rowSelector + "," // Build pattern with rowSelector
  regex := regexp.MustCompile(pattern)
  for _, line := range lines {
    if regex.MatchString(line) {
      return line, true
    }
  }
  return "", false
}

// ------------------------------------------------------------------------

func main() {
  var separator string
  var verbose bool

  // Process commandline flags and args with flag package
  // ----------------------------------------------------------------------
  flag.StringVar(&separator, "s", "=", "") // flag desc unused
  flag.BoolVar(&verbose, "v", false, "")   // flag deec unused
  flag.Usage = func() {
    progName := filepath.Base(os.Args[0])
    usage = strings.ReplaceAll(usage, "[progName]", progName)
    fmt.Fprintf(os.Stderr, "%s\n", usage)
  }
  flag.Parse()

  args := flag.Args()

  if len(args) < 2 {
    flag.Usage()
    return
  }

  rowSelector := args[0]
  fileLocator := args[1]

  // ------------------------------------------------------------------------
  // Fetch CSV content
  csvContent, err := getFileContent(fileLocator)
  if err != nil {
    fmt.Fprintf(os.Stderr, "Error: %s\n", err)
    return
  }

  if verbose {
    fmt.Fprintf(os.Stderr, "Fetched CSV content:\n")
    fmt.Fprintf(os.Stderr, "%s\n\n", csvContent)
  }

  // ------------------------------------------------------------------------
  // Process CSV content
  lines := strings.Split(csvContent, "\n")

  if len(lines) < 2 {
    if verbose {
      fmt.Fprintf(os.Stderr, "Warning: CSV contains insuffient content.\n")
    }
    return
  }

  headerLine := lines[0]
  recordLine, found := getRecordByKey(lines[1:], rowSelector)

  if found {
    headers := strings.Split(headerLine, ",")
    values := strings.Split(recordLine, ",")

    for i, header := range headers {
      if strings.ToUpper(header) == header { // Consider only allcaps headers
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
    fmt.Fprintf(os.Stderr, "Waning: Pattern not found.\n")
  }
}
