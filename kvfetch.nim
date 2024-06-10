# kvfetch.nim v1.0
# 
# MIT License (https://opensource.org/licenses/MIT)
#
# compilation with nim:
#   `nim -d:release --gc:orc c kvfetch.nim`

let usage = """
kvfetch v1.0, ouput selected CSV data as key-value pairs
Usage: kvfetch <RECORD> <SOURCE>

Where:
  <RECORD>   Selects target row by first column value.
  <SOURCE>   Specifies CSV location as URL, file path, 
             or rclone remote.
             Files may contain either CSV data or URL.

Exit Status Codes:
  0 - Success
  1 - Insufficient arguments
  2 - Failure to retrieve source
  3 - Retrieved source is empty
  4 - No match for specified record
"""

import
  os, osproc, strutils

const
  EXIT_SUCCESS = 0
  EXIT_INSUFFICIENT_ARGS = 1
  EXIT_FAILURE_TO_RETRIEVE_SOURCE = 2
  EXIT_RETRIEVED_SOURCE_EMPTY = 3
  EXIT_NO_MATCH_FOR_RECORD = 4

proc isURL(input: string): bool =
  input.find("://") != -1

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
  echo usage.replace("kvfetch",progName)
  quit(EXIT_INSUFFICIENT_ARGS)

else:
  let
    rowSelector = paramStr(1)
    fileLocator = paramStr(2)
    fileContent = getFileContent(fileLocator)
    topRowElems = fileContent.split("\n")[0].split(",")
    selRowElems = getRowMatchingSelector(fileContent, rowSelector).split(",")

  if selRowElems.len > 2:
    printInPairs(topRowElems, selRowElems)

quit(EXIT_SUCCESS)
