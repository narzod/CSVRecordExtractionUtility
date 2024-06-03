#!/usr/bin/awk -f

#  csv2ini.awk
#  Filters CSV based on key index field and outputs INI-like config.
#
#  Usage: awk -f csv2ini.awk -v key=<keyindex> [-v out=<outfile>]
#  Example: csv2ini.awk -v key=F1 -v out=output.ini input.csv

BEGIN {
  if (key == "") {
    usage = "csv2ini.awk -v key=<keyindex> [-v out=<outfile>]"
    print "usage:", usage > "/dev/stderr";
    exit_now = 1;
    exit 1;
  }

  if (out == "") { out = "/dev/stdout"; }

  FS = ",";
  found = 0;
}

# Process headers
exit_now != 1 && NR == 1 {
  sub("\r", ""); gsub("\"", "");
  for (i = 1; i <= NF; i++) { headers[i] = $i; }
  next;
}

# Process matching row
exit_now != 1 && toupper($1) == toupper(key) {
  found = 1;
  sub("\r", ""); gsub("\"", "");
  for (i = 1; i <= NF; i++) {
    if (headers[i] == toupper(headers[i])) {
      printf("%s=%s\n", headers[i], $i) > out;
    }
  }
}

END {
  if (exit_now != 1 && found == 0) {
    print "Configuration not found" > "/dev/stderr";
  }
}
