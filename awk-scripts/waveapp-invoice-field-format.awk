# Produce Wave Account App compatible invoice Google Sheets import data
#
# Confirms input file is a valid final ClinicSense transaction CSV data file
#
# Valid fields:
#   Date,Client,Practitioner,Primary Service,Reference Number,Payment Method,Batch No.,Total Amount,Subtotal,Tax Rate,Tax Name,Tax Amount
#
# Run as:
#
#     $ gawk -v invrev=$INVREV -f waveapp-invoice-field-format.awk $CSV
#
#     Where:
#
#     $INVREV INVoice REVision is appended to invoice number in event of re-upload to Wave. Default: NULL
#             Preferred scheme (A,B,C,D,E...)

BEGIN { 
  FPAT = "[^,\"]*|\"([^\"]|\"\")*\""
  CONVFMT = "%2.2f"
  anon_client_title = "ClinicSense Clients"
  file_field_validator = "Date,Client,Practitioner,Primary Service,Reference Number,Payment Method,Batch No.,Total Amount,Subtotal,Tax Rate,Tax Name,Tax Amount"
  outputfields = "Invoice Number,Customer Name,Invoice Date,Disable Card Payments,Disable Amex Payments,Disable Bank Payments,Memo,Item Column Title,Hide Quantity Column,Item Name,Quantity,Unit Price,Description,Sales Taxes"
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
  #customer_name = $2
  customer_name = anon_client_title
  invoice_date = $1
  gdate_command_1 = "gdate -d " $1 " +%Y/%m/%d"
  gdate_command_1 | getline invoice_date_conv_full
  gdate_command_2 = "gdate -d " $1 " +%Y%m"
  gdate_command_2 | getline invoice_date_conv_month
  if (length(invrev) != 0) { invoice_number = strtonum($1) "-" invrev } else { invoice_number = invoice_date_conv_month }
  disable_card_payments = "Disable"
  disable_amex_payments = "Disable"
  disable_bank_payments = "Disable"
  memo = "[ " strftime("ClinicSense Import: %m/%d/%Y %H:%M:%S", systime()) " ]"
  item_column_title = "Service"
  hide_description_column = "Show (Default)"
  hide_quantity_column = "Hide"
  item_name = $4
  quantity = 1
  unit_price = $9
  description = "[Invoice: " $5 " (" invoice_date_conv_full ") | Payment: " $6 " | Paystone Batch: " $7 "]"
  sales_taxes = $11

  # Field Order: Invoice Number, Customer Name, Invoice Date, Disable Card Payments, Disable Amex Payments, Disable Bank Payments, Memo, Item Column Title, Hide Quantity Column, Item Name, Quantity, Unit Price, Description, Sales Taxes
  printf("%d,%s,%s,%s,%s,%s,%s,%s,%s,%s,%d,%2.2f,%s,%s\n",invoice_number,customer_name,invoice_date,disable_card_payments,disable_amex_payments,disable_bank_payments,memo,item_column_title,hide_quantity_column,item_name,quantity,unit_price,description,sales_taxes)
}
