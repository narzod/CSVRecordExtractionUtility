import
  os, osproc, strutils

proc isURL(input: string): bool =
  return input.find("://") != -1

proc getFileContent(fileLocator: string): string =
    if fileLocator.endswith(":"):
        return ""

    let cmd = case isURL(fileLocator):
        of true: "rclone copyurl " & fileLocator & " --stdout"
        of false: "rclone cat " & fileLocator

    var (content, _) = execCmdEx(cmd)
    content = content.strip()

    if isURL(content):
        return getFileContent(content)

    return content

proc getRowMatchingSelector(content: string, rowSelector: string): string =
  for line in content.splitLines():
    if line.startswith(rowSelector & ","):
      return line

proc printInPairs(header: seq[string], row: seq[string]): void =
  for i, headerElem in header.pairs:
    if i < row.len and headerElem == headerElem.toUpperAscii():
      echo headerElem, "=", row[i]

proc main() =
  if paramCount() < 2:
    echo "Usage: csvrow row_selector file_locator"
  else:
    let rowSelector = paramStr(1)
    let fileLocator = paramStr(2)
    let fileContent = getFileContent(fileLocator)
    let headerRow = fileContent.split("\n")[0].split(",")
    let matchingRow = getRowMatchingSelector(fileContent, rowSelector).split(",")
    if matchingRow.len > 2:
      printInPairs(headerRow, matchingRow)

when isMainModule:
  main()
