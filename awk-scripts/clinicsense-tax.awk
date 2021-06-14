# Calculate tax on processed ClinicSense csv data
#
# Confirms input file is a valid processed ClinicSense CSV data file
#
# Valid fields:
#   Date,Client,Practitioner,Primary Service,Reference Number,Payment Method,Amount,Batch No.
#
# Run as:
#
#     $ gawk -v taxrate=$TAXRATE -f clinicsense-tax.awk $CSV
#
#     Where:
#
#     $TAXRATE is a number representing tax rate percent (e.g. 13 = 13%). Default: 13
#

BEGIN { 
  FPAT = "([^,]+)|(\"[^\"]+\")"
  CONVFMT = "%.2f"
  OFMT = "%.2f"
  file_field_validator = "Date,Client,Practitioner,Primary Service,Reference Number,Payment Method,Amount,Batch No."
  reordered_fields = "Date,Client,Practitioner,Primary Service,Reference Number,Payment Method,Batch No."
  outputfields = reordered_fields ",Total Amount,Subtotal,Tax Rate,Tax Name,Tax Amount"
  tax_name = "HST"
  adjItemName = "Rounding Adjustment"

  # defaults to 13% tax rate (e.g. Canadian HST)
  if (taxrate == "") {
    taxrate=13
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
  amount = $7
  gsub(/[$]/,"",amount)

  subtotal = (amount * 100)/(taxrate+100)
  taxamount = amount - subtotal

  printf("%s,%s,%s,%s,%s,%s,%s,%.2f,%.2f,%d%,%s,%.2f\n",$1,$2,$3,$4,$5,$6,$8,amount,subtotal,taxrate,tax_name,taxamount)

  # account for rounding problems by rounding subtotal to x.00 -> calculate sales tax -> round again
  rndSubtotal = round(subtotal,2)
  postTaxCalcAmount = round((rndSubtotal * (1 + taxrate/100)),2)

  rndAdjustment = amount - postTaxCalcAmount

  # show rounding adjustment
  if (rndAdjustment != 0.00) {
    printf("%s,%s,%s,%s,%s,%s,%s,%.2f,%.2f,%d%,%s,%.2f\n",$1,$2,$3,adjItemName,$5,$6,$8,"",rndAdjustment,"","","")
  }

}

function round(x, p,   s) {
  # DESC:     Rounds float to the number of decimals specified
  # ARGS:     x (required)  - number to round. float valid
  #           p             - decimal place value rounded to
  #                           defaults 1 if unspecified.
  # RETURN:   rounded float
  # USAGE:    round(5.25,2) 
  # NOTES:    Handles positive/negative floats & integers
  p = 10^p
  s = 1

  if (x < 0) { x = -x; s = -1; }
  return s * int(x * p + .5) / p
}