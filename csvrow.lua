#!/usr/bin/env lua

--[[ csvrow.lua, v1.0

Extracts a specified record from a CSV file, local or remote, and
prints it in an INI-like format.

Usage: csvrow.lua <key> <csv-input>

Arguments:
  <key>         Specifies a value matching the first field in the target row.
  <csv-input>   Specifies a URL or a file corresponding to CSV data, which
                may contain data or a URL to the data.

------------------------------------------------------------------------------]]

local sep = "="
local exit_status = 0

-- Function to check if a string is a URL
function is_url(str)
    local pattern = "^https?://[%w-_%.%?%.:/%+=&]+$"
    return string.match(str, pattern) ~= nil
end

-- Function to retrieve CSV content from a local or remote source
function get_csv(input)
    local command
    if is_url(input) then
        command = "rclone copyurl --stdout " .. input
    else
        command = "rclone cat " .. input
    end

    local handle = io.popen(command)
    local csv_content = handle:read("*a")
    handle:close()
    
    -- Normalize line endings to Unix style
    csv_content = csv_content:gsub("\r\n", "\n"):gsub("\r", "\n")

    -- Trim any leading/trailing whitespace from the content
    csv_content = csv_content:match("^%s*(.-)%s*$")
    
    if is_url(csv_content) then
        return get_csv(csv_content)
    else
        return csv_content
    end
end

-- Function to parse CSV string into a table of lines
function csv_to_table(csv_string)
    local result = {}
    for line in csv_string:gmatch("[^\r\n]+") do
        table.insert(result, line)
    end
    return result
end

-- Function to convert a CSV record to INI-like format
function csv_record_to_ini(csv_lines, match)
    local headers = {}
    local values = {}
    for i, line in ipairs(csv_lines) do
        local fields = {}
        for field in line:gmatch("([^,]+)") do
            table.insert(fields, field)
        end
        if i == 1 then
            headers = fields
        elseif fields[1] == match then
            values = fields
            break
        end
    end

    if #values == 0 then
        return nil
    end

    local ini_content = {}
    for i = 1, #headers do
        if string.upper(headers[i]) == headers[i] then
            local line = string.format("%s%s%s", headers[i], sep, values[i])
            table.insert(ini_content, line)
        end
    end

    if #ini_content == 0 then
        return nil -- For edge case when all headers not in preferred allcaps
    else
        return table.concat(ini_content, "\n")
    end
end

-- Function to print usage
function usage()
    print("csvrow.lua 1.0, prints specified CSV row data alongside headers " ..
          "in INI-like format.")
    print("Usage: csvrow.lua <key> <csv-input>\n")
    print("Where:")
    print("  <key>         Specifies a value matching the first field " ..
                           "in the target row.")
    print("  <csv-input>   Specifies a URL or a file corresponding to " .. 
                           "CSV data, which")
    print("                may contain data or a URL to the data.\n")
end

if #arg < 2 then
    usage()
    os.exit(1)
end

local record_to_match = arg[1]
local input = arg[2]

local csv_content = get_csv(input)
local csv_lines = csv_to_table(csv_content)
local ini_output = csv_record_to_ini(csv_lines, record_to_match)

if ini_output then
    print(ini_output)
else
    -- Do nothing (no ouput)
    exit_status = 1
end
os.exit(exit_status)
