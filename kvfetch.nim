# kvfetch.nim v1.0
# retrieve CSV data and dump selected key-value pairs
# 
# MIT License (https://opensource.org/licenses/MIT)
#
# usage: kvfetch <record> <source>
#
# <record> specifies target row by first column match
# <source> specifies URL, file path, or rclone remote
#          files may contain either CSV data or a URL
#
# compilation with nim:
#   `$ nim -d:release --gc:orc c kvfetch.nim`

import
  os, osproc, strutils

const
  EXIT_SUCCESS = 0
  EXIT_INSUFFICIENT_ARGS = 1
  EXIT_FAILURE_TO_RETRIEVE_SOURCE = 2
  EXIT_RETRIEVED_SOURCE_EMPTY = 3
  EXIT_NO_MATCH_FOR_RECORD = 4

proc isURL(input: string): bool =
  return input.find("://") != -1

proc getFileContent(fileLocator: string): string =
  if fileLocator.endswith(":"):
    quit(EXIT_FAILURE_TO_RETRIEVE_SOURCE)

  let isFile = not isURL(fileLocator)
  let cmd = case isFile:
    of true: "rclone cat " & fileLocator
    of false: "rclone copyurl " & fileLocator & " --stdout"

  var (content, status) = execCmdEx(cmd)
  content = content.strip()

  if status > 0:
    quit(EXIT_FAILURE_TO_RETRIEVE_SOURCE)

  if content.len == 0:
    quit(EXIT_RETRIEVED_SOURCE_EMPTY)

  if isFile and isURL(content):
    return getFileContent(content)

  return content

proc getRowMatchingSelector(content: string, rowSelector: string): string =
  for line in content.splitLines()[1..^1]:
    if line.startswith(rowSelector & ","):
      return line
  quit(EXIT_NO_MATCH_FOR_RECORD)

proc printInPairs(header: seq[string], row: seq[string]): void =
  for i, headerElem in header.pairs:
    if i < row.len and headerElem == headerElem.toUpper():
      echo headerElem, "=", row[i]

if paramCount() < 2:
  let progName = paramStr(0).splitPath().tail
  echo progName & " - retrieve CSV data and dump selected key-value pairs\n"
  echo "Usage: " & progName & " <record> <source>\n"
  echo "Where:"
  echo "  <record>    Matches the first column of the target row."
  echo "  <source>    Specifies URL, file path, or rclone remote."
  echo "              Files may contain either CSV data or a URL.\n"
  echo "Exit Status Codes:"
  echo "  0 - Success"
  echo "  1 - Insufficient arguments"
  echo "  2 - Failure to retrieve source"
  echo "  3 - Retrieved source is empty"
  echo "  4 - No match for specified record"
  quit(EXIT_INSUFFICIENT_ARGS)
else:
  let rowSelector = paramStr(1)
  let fileLocator = paramStr(2)
  let fileContent = getFileContent(fileLocator)
  let topRowElems = fileContent.split("\n")[0].split(",")
  let selRowElems = getRowMatchingSelector(fileContent, rowSelector).split(",")

  if selRowElems.len > 2:
    printInPairs(topRowElems, selRowElems)

quit(EXIT_SUCCESS)
