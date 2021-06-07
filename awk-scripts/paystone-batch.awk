# Parse a Paystone payment processing batch settlement csv report
#
# Confirms input file is a valid Paystone batch settlement csv, allows one
# to specify desired output fields and format settlement date/time in desired
# <date> compatible format characters (e.g. +'%A, %d %B %Y')
#
# Valid fields:
#   MID,Name,Terminal ID,Batch No.,Transaction Count,Amount,Settlement Date,Settlement Time
#
# Run as:
#
#     $ gawk -v dateformat=$DATEFORMAT batchonly=$BATCHONLY(TRUE|FALSE) -f paystone.batch.awk $BATCHCSV
#
#     Where:
#
#     $DATEFORMAT is a string representing the <date> command formating characters
#       Select list of date command formating characters:
#       Need more? -> https://man7.org/linux/man-pages/man1/date.1.html
#
#         %a - Locale’s abbreviated short weekday name (e.g., Mon)
#         %A - Locale’s abbreviated full weekday name (e.g., Monday)
#         %b - Locale’s abbreviated short month name (e.g., Jan)
#         %B - Locale’s abbreviated long month name (e.g., January)
#         %d - Day of month (e.g., 01)
#         %H - Hour (00..23)
#         %I - Hour (01..12)
#         %j - Day of year (001..366)
#         %m - Month (01..12)
#         %M - Minute (00..59)
#         %S - Second (00..60)
#         %u - Day of week (1..7)
#         %Y - Full year (e.g., 2019)
#
#       example for %b %d, %Y   (Mar 11, 2020)
#
#     $BATCHONLY(TRUE|FALSE). Default=FALSE is a boolean for exporting a subset of the fields 
#     which includes only:  Settlement Date,Batch No.,Transaction Count,Amount

BEGIN { 
  FPAT = "([^,]+)|(\"[^\"]+\")"
  file_field_validator = "MID,Name,Terminal ID,Batch No.,Transaction Count,Amount,Settlement Date,Settlement Time"
  batchonly_fields = "Settlement Date,Batch No.,Transaction Count,Amount"

  # defaults to NOT include settlement time as part of the date
  if (batchonly == "" || toupper(batchonly) != "TRUE") {
    batchonly = "FALSE"
    outputfields = file_field_validator
  } else {
    outputfields = batchonly_fields
  }

  # defaults to original date only format OR original date format with original time format
  if (dateformat == "") {
    dateformat = "%B %d, %Y"
  }
  
}

NR==1 {
  if (NF != 8 || $0 != file_field_validator) {
    print "File did not pass validation!\n"
    print "Found: " $0
    print "Expected: " file_field_validator
    print "NF = ", NF
    for (i = 1; i <= NF; i++) {
        printf("$%d = <%s>\n", i, $i)
    }
    exit
  } else {
    print outputfields
  }
}

NR>1 {
  mid = $1
  name = $2
  terminal_id = $3
  batch_no = $4
  transaction_count = $5
  amount = $6
  settlement_date = $7
  settlement_time = $8

  default_dateformat = "%B %d, %Y"
  transform_dateformat = dateformat

  cmd = "date -jf \47" default_dateformat "\47 " settlement_date " +\47" transform_dateformat "\47"
  cmd | getline settlement_date

  if (toupper(batchonly) != "TRUE") {
    printf ("%i,%s,%s,%i,%i,%4.2f,\"%s\",%s\n", mid, name, terminal_id, batch_no, transaction_count, amount, settlement_date, settlement_time)
  } else {
    printf ("\"%s\",%i,%i,%4.2f\n", settlement_date, batch_no, transaction_count, amount)
  }
  close(cmd)
}
