# Reformat some ClinicSense csv data fields
#
# Confirms input file is a valid combined ClinicSense & Paystone CSV data file
#
# Valid fields:
#   Date,Client,Practitioner,Primary Service,Reference Number,Payment Method,Batch No.,Total Amount,Subtotal,Tax Rate,Tax Name,Tax Amount
#
# Run as:
#
#     $ gawk -f clinicsense-field-format.awk $CSV
#
# Reformating steps:
#   - PRIMARY SERVICE: remove duplicated leading time
#   - REFERENCE NUMBER: remove "Invoice #" prefix to leave only #
#   - BATCH NO.: remove IF PAYMENT METHOD=GC|Cash|Other (the ClinicSense/Paystone join is a better place for this)

BEGIN { 
  FPAT = "[^,\"]*|\"([^\"]|\"\")*\""
  CONVFMT = "%2.2f"
  file_field_validator = "Date,Client,Practitioner,Primary Service,Reference Number,Payment Method,Batch No.,Total Amount,Subtotal,Tax Rate,Tax Name,Tax Amount"
  outputfields = file_field_validator
}

NR==1 {
  if (NF != 12 || $0 != file_field_validator) {
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
  # PRIMARY SERVICE: remove duplicated leading time
  primary_service=$4
  sub(/.. minute /,"",primary_service)

  # PRIMARY SERVICE: Convert to Title Case
  n = split(primary_service, primary_service_words, /[ |]/, primary_service_separators)
  out = primary_service_separators[0]
  for (i=1; i<=n; ++i) {
     out = out toupper(substr(primary_service_words[i],1,1)) tolower(substr(primary_service_words[i],2)) primary_service_separators[i];
  }
  primary_service = out
  # print out primary_service_separators[n+1];

  # REFERENCE NUMBER: remove "Invoice #" prefix to leave only #
  reference_number=$5
  sub(/Invoice #/,"",reference_number)

  # BATCH NO.: remove IF PAYMENT METHOD=GC|Cash|Other (the ClinicSense/Paystone join is a better place for this)
  if ($6 == "Cash" || $6 == "Other" || $7 == "" || match($6,/GC/)) {
    batch_number = "0"
  } else {
    batch_number = $7
  }


  printf("%s,%s,%s,%s,%s,%s,%s,%2.2f,%2.2f,%d%,%s,%2.2f\n",$1,$2,$3,primary_service,reference_number,$6,batch_number,$8,$9,$10,$11,$12)
}
