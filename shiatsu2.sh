#!/bin/bash

# ##################################################
# Shiatsu
#  Carl Hoyer (carl@hoyer.ca)
#
# A script to massage exported data from ClinicSense (https://clinicsense.com) 
# and Paystone Hub (https://hub.paystone.com) for the purpose of importing 
# as into the Wave Accounting App (https://www.waveapps.com).
#
# This has grown to the point where it would be better written in an actual
# programming language. But that will have to wait for another day.
#
version="2.1.0"               # Sets version variable
#
#
# HISTORY:
#
# * 07/06/2021 - v2.1.0  - Anonymize client names and
#                          consolidate in daily invoice.
#
# * 06/04/2021 - v2.0.0  - Incorporated Nathaniel Landau's 
#                          amazing BASH script utils.
#
# * 06/01/2021 - v1.0.0  - First Formalized Creation. A pale
#                          shadow of what it is today.
#
#
# THANKS:
#  Nate Landau and his bash scripting helpers
#  https://github.com/natelandau/dotfiles/tree/master/scripting
#
# ##################################################

# Provide a variable with the location of this script.
scriptPath="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

# Location of AWK scripts
awkScriptDir="${scriptPath}/awk-scripts"

# Source Scripting Utilities
# -----------------------------------
# These shared utilities provide many functions which are needed to provide
# the functionality in this script. This script will fail if they can
# not be found.
# -----------------------------------
utilsDir="${scriptPath}/helpers" # Update this path to find the utilities.

_sourceHelperFiles_() {
  # DESC: Sources script helper files.
  local filesToSource
  local sourceFile
  filesToSource=(
    "${utilsDir}/baseHelpers.bash"
    #"${utilsDir}/arrays.bash"
    "${utilsDir}/files.bash"
    #"${utilsDir}/macOS.bash"
    #"${utilsDir}/numbers.bash"
    #"${utilsDir}/services.bash"
    #"${utilsDir}/textProcessing.bash"
    #"${utilsDir}/dates.bash"
  )
  for sourceFile in "${filesToSource[@]}"; do
    [ ! -f "${sourceFile}" ] \
      && {
        echo "error: Can not find sourcefile '$sourceFile'."
        echo "exiting..."
        exit 1
      }
    source "${sourceFile}"
  done
}
_sourceHelperFiles_

# Base directory to store working data
baseDataDir="./shiatsu-data"

# Set initial flags
keepworkingdir=false
quiet=false
printLog=false
LOGLEVEL=ERROR
verbose=false
force=false
dryrun=false
declare -a args=()


_mainScript_() {

  printf ${tan}
  cat <<'EOF'
           __    _       __            
     _____/ /_  (_)___ _/ /________  __
    / ___/ __ \/ / __ `/ __/ ___/ / / /2
   (__  ) / / / / /_/ / /_(__  ) /_/ / 
  /____/_/ /_/_/\__,_/\__/____/\__,_/
       massaging data like it's 1984

EOF
  printf ${reset}

  header "Prerequisite Check"

  # Check to see if gawk is installed
  (_checkBinary_ gawk ) && success "gawk found" || fatal "gawk not found. please install before running script!"

  # Check to see if xsv is installed
  (_checkBinary_ xsv ) && success "xsv found" || fatal "xsv not found. please install before running script!"

  # Check to see if lolcat is installed
  (_checkBinary_ lolcat ) && success "lolcat found. phew!" || warning "lolcat not found. maximum awesomeness not achievable!"

  # Create the working DATA working directory
  header "Creating Data Working Directory"

  # Working data directory for current execution of script
  workingDataDir="${baseDataDir}/${timestamp}"

  [ -d ${workingDataDir} ] && error "Directory already exists: ${workingDataDir}" || info "Creating: ${workingDataDir}" && mkdir -p ${workingDataDir}
  success "Created: ${workingDataDir}"

  # Look in the current directory for CSV files
  # Expecting to find the following files:
  #  - paystone batch csv
  #  - revenue 
  find . -maxdepth 1 -type f -name "*.csv" -print0 | while IFS= read -r -d '' file; do
      
    header "File: [$file]"
    
    l=`sed '/[^[:blank:]]/q;d' "$file"` # find the first non-blank line in file
    line=${l%%,*}
    
    verbose "First Line: [$line]"

    case "$line" in
      "MID")

        fileType="paystone"
        typeDescription="Paystone Batch CSV"
        notice "Recognized File Format: ${bold}${blue}${typeDescription}${reset}"

        filename="${workingDataDir}/${fileType}-original.csv"
        procFilename="${workingDataDir}/${fileType}-batchonly.csv"
        _execute_ -s "cp \"${file}\" \"${filename}\"" "File copied -> ${filename}"

        # verify Paystone batch file to be valid, reformat date and return subset of data
        _execute_ -s "gawk -v dateformat=\"%b %d, %Y\" -v batchonly=true -f \"${awkScriptDir}/paystone-batch.awk\" \
                        \"${file}\" > \"${procFilename}\"" \
                        "${typeDescription} verification / date reformat / return data subset"

        info "Processed ${typeDescription} -> ${procFilename}"

      ;;
      "Revenue Report")

        fileType="revenue"
        typeDescription="ClinicSense Revenue CSV"
        notice "Recognized File Format: ${bold}${blue}${typeDescription}${reset}"
        notice "IGNORING ${typeDescription}: Not important!"
        # For the time being this report is not used and ignored.

      ;;
      "Payments Report")

        fileType="payment"
        typeDescription="ClinicSense Payment CSV"
        notice "Recognized File Format: ${bold}${blue}${typeDescription}${reset}"

        filename="${workingDataDir}/${fileType}-original.csv"
        _execute_ -s "cp \"${file}\" \"${filename}\"" "File copied -> ${filename}"

        _execute_ -s "xsv slice --no-headers --end 9 --output \"${workingDataDir}/${fileType}-header.csv\" \"${file}\"" \
                        "XSV slice: HEADER -> ${workingDataDir}/${fileType}-header.csv"

        _execute_ -s "xsv slice --no-headers --start 9 --output \"${workingDataDir}/${fileType}-data.csv\" \"${file}\"" \
                        "XSV slice: DATA -> ${workingDataDir}/${fileType}-data.csv"

        _execute_ -s "xsv index \"${workingDataDir}/${fileType}-data.csv\"" "XSV index: ${workingDataDir}/${fileType}-data.csv"

      ;;
      "Appointment Report")

        fileType="appointment"
        typeDescription="ClinicSense Appointment CSV"
        notice "Recognized File Format: ${bold}${blue}${typeDescription}${reset}"

        filename="${workingDataDir}/${fileType}-original.csv"
        _execute_ -s "cp \"${file}\" \"${filename}\"" "File copied -> ${filename}"

        _execute_ -s "xsv slice --no-headers --end 7 --output \"${workingDataDir}/${fileType}-header.csv\" \"${file}\"" \
                        "XSV slice: HEADER -> ${workingDataDir}/${fileType}-header.csv"

        _execute_ -s "xsv slice --no-headers --start 7 --output \"${workingDataDir}/${fileType}-data.csv\" \"${file}\"" \
                        "XSV slice: DATA -> ${workingDataDir}/${fileType}-data.csv"

        _execute_ -s "xsv index \"${workingDataDir}/${fileType}-data.csv\"" "XSV index: ${workingDataDir}/${fileType}-data.csv"

      ;;
      *) notice "This file will be ignored!" ;;
    esac

  done

  # TODO (choyer): verify header record counts match # record lines in sliced data file for all ClinicSense CSV files

  # Begin joining data files
  header "File Joining Data Processing"

  notice "==== Appointment Details ===="

  # Date range of data records based on ClinicSense header
  local headerApptDate=$(xsv search -n "Date:" ${workingDataDir}/appointment-header.csv | xsv select 2)
  info "Appointment Date Range: ${bold}${headerApptDate}${reset}"

  # Number of expected appointment records based on ClinicSense header
  local -i headerApptCount=$(xsv search -n "Total Appointments:" ${workingDataDir}/appointment-header.csv | xsv select 2)
  info "Total Appointment Header Count: ${bold}${headerApptCount}${reset}"

  # Count Total records in appointment data file.
  local -i totalApptCount=$(xsv count ${workingDataDir}/appointment-data.csv)
  info "Total Appointment Count: ${bold}${totalApptCount}${reset}"

  # Record count from header should match count in the actual data file. Warn if not.
  [[ ${headerApptCount} == ${totalApptCount} ]] && success "[RECONCILE ✔] Pre-Join ClinicSense Appointment counts match header value" || warning "[RECONCILE ✖] Pre-Join ClinicSense Appointment counts DO NOT match header value"

  # Count 'Canceled' records in data file. These records will be omitted for the time being, but lets keep track of the count for reconciliation
  local -i totalCancAppt=$(xsv search "\[(Canceled)\]" ${workingDataDir}/appointment-data.csv | xsv count)
  info "Total Canceled Appointment Count: ${bold}${totalCancAppt}${reset}"

  # Count 'No-show' records in data file. These records are kept as no-shows can be charged to customer in some cases.
  local -i totalNoShowAppt=$(xsv search "\[(No-show)\]" ${workingDataDir}/appointment-data.csv | xsv count)
  info "Total No-show Appointment Count: ${bold}${totalNoShowAppt}${reset}"

  local -i totalApptExpectCount=$(( totalApptCount - totalCancAppt ))
  info "Total Available Pre-Join Appointment Count: ${bold}${totalApptExpectCount}${reset} (Total: ${totalApptCount} - Canceled: ${totalCancAppt})"

  notice "==== Payment Details ===="

  # Date range of data records based on ClinicSense header
  local headerPayDate=$(xsv search -n "Date:" ${workingDataDir}/payment-header.csv | xsv select 2)
  info "Payment Date Range: ${bold}${headerPayDate}${reset}"

  # Number of expected payments records based on ClinicSense header
  local -i headerPayCount=$(xsv search -n "# of Payments" ${workingDataDir}/payment-header.csv | xsv select 2)
  info "Total Payments Header Count: ${bold}${headerPayCount}${reset}"

  # Count Total records in payment data file.
  local -i totalPayCount=$(xsv count ${workingDataDir}/payment-data.csv)
  info "Total Payment Count: ${bold}${totalPayCount}${reset}"

  # Record count from header should match count in the actual data file. Warn if not.
  [[ ${headerPayCount} == ${totalPayCount} ]] && success "[RECONCILE ✔] Pre-Join ClinicSense Payment counts match header value" || warning "[RECONCILE ✖] Pre-Join ClinicSense Payment counts DO NOT match header value"


  notice "==== Compairing Appointment & Payment Data ===="

  # Compare number of Appointments (-canceled) to Payments records
  [[ ${totalApptExpectCount} == ${totalPayCount} ]] && success "[RECONCILE ✔] ClinicSense Appointment count matches Payment count" || warning "[RECONCILE ✖] ClinicSense Appointment count (${totalApptExpectCount}) DOES NOT matches Payment count (${totalPayCount})"  


  notice "==== Performing Appointment/Payment Join ===="
  
  # Join ClinicSense Appointment & Payment data WHERE NOT canceled
  _execute_ -s "xsv join --no-case Date,Client \"${workingDataDir}/appointment-data.csv\" Date,Client \"${workingDataDir}/payment-data.csv\" \
                  | xsv select \"Date[1],Client[1],Practitioner,Primary Service,Reference Number,Payment Method,Amount\" \
                  | xsv search \"\[(Canceled)\]\" --invert-match \
                  > \"${workingDataDir}/clinicsense-joined-data.csv\"" "Joining ClinicSense APPOINTMENT & PAYMENT data"

  # Count total appointments post payment data join
  local -i totalApptPostPayJoin=$(xsv count ${workingDataDir}/clinicsense-joined-data.csv)
  info "Post-Join ClinicSense Appointment Payment Count: ${bold}${totalApptPostPayJoin}${reset}"

  info "Joined ClinicSense APPOINTMENT & PAYMENT data -> ${workingDataDir}/clinicsense-joined-data.csv"


  notice "==== Performing ClinicSense/Paystone Join ===="

  # Show Paystone Batch data date range
  local batchDateMin=$(xsv stats -s 1 ${workingDataDir}/paystone-batchonly.csv | xsv select min)
  local batchDateMax=$(xsv stats -s 1 ${workingDataDir}/paystone-batchonly.csv | xsv select max)
  info "Paystone Batch Data Date Range: ${bold}${batchDateMin//$'\n'/ } to ${batchDateMax//$'\n'/ }${reset}"

  # Count Total records in Paystone Batch data file.
  local -i totalBatchCount=$(xsv count ${workingDataDir}/paystone-batchonly.csv)
  info "Total Paystone Batch Count: ${bold}${totalBatchCount}${reset}"

  # Join ClinicSense Data with Paystone data to associate batch # to each ClinicSense record
  _execute_ -s "xsv join --left --no-case Date \"${workingDataDir}/clinicsense-joined-data.csv\" 'Settlement Date' \"${workingDataDir}/paystone-batchonly.csv\" \
                  | xsv select 'Date,Client,Practitioner,Primary Service,Reference Number,Payment Method,Amount,Batch No.' \
                  > \"${workingDataDir}/clincsense-paystone-data.csv\"" "Joining ClinicSense & Paystone Batch data"

  info "Joined ClinicSense & Paystone Batch data -> ${workingDataDir}/clincsense-paystone-data.csv"

  # Count Total records following ClinicSense Appointment/Payment & Paystone Batch data file join.
  local -i totalCount=$(xsv count ${workingDataDir}/clincsense-paystone-data.csv)
  notice "==> Final Joined Record Count: ${bold}${totalCount}${reset}"


  header "Post Join Data Processing"

  # Calculate sales tax amounts
  _execute_ -s "gawk -f \"${awkScriptDir}/clinicsense-tax.awk\" \"${workingDataDir}/clincsense-paystone-data.csv\" \
                > \"${workingDataDir}/service-transaction-data.csv\"" \
                "Calculate Sales Tax & Rounding Adjustments"

  # Final pass over data to format it just right
  _execute_ -s "gawk -f \"${awkScriptDir}/clinicsense-field-format.awk\" \"${workingDataDir}/service-transaction-data.csv\" \
                  > \"${workingDataDir}/clinicsense-final-data.csv\"" \
                  "Final data formating"


  header "Wave Accounting Data File Generation"

  # Wave Accounting: Generate Invoice Data
  _execute_ -s "gawk -f \"${awkScriptDir}/waveapp-invoice-field-format.awk\" \"${workingDataDir}/clinicsense-final-data.csv\" \
                  > \"./waveapp-invoice-import-data.csv\"" \
                  "Generate Invoice Import Data"
  info " ${blue}↳${reset} Invoice record count: ${bold}$(xsv count ./waveapp-invoice-import-data.csv)${reset}"
  _backupFile_ "./waveapp-invoice-import-data.csv" "${workingDataDir}"

  # Wave Accounting: Generate Service List
  _execute_ -s "xsv search -s \"Item Name\" '.*' \"${workingDataDir}/waveapp-invoice-import-data.csv\" \
                  | xsv select \"Item Name\" \
                  | sort --unique > \"./waveapp-service-import-data.csv\"" \
                  "Generate Service Import Data"
  info " ${blue}↳${reset} Service record count: ${bold}$(xsv count ./waveapp-service-import-data.csv)${reset}"
  _backupFile_ "./waveapp-service-import-data.csv" "${workingDataDir}"

  # Wave Accounting: Generate Customer List
  _execute_ -s "xsv search -s \"Customer Name\" '.*' \"${workingDataDir}/waveapp-invoice-import-data.csv\" \
                  | xsv select \"Customer Name\" \
                  | sort --unique > \"./waveapp-customer-import-data.csv\"" \
                  "Generate Customer Import Data"
  info " ${blue}↳${reset} Customer record count: ${bold}$(xsv count ./waveapp-customer-import-data.csv)${reset}"
  _backupFile_ "./waveapp-customer-import-data.csv" "${workingDataDir}"


  header "Your Files Are Ready"
  info "Use the following files with the Google Sheets Wave Connect add-in to upload data:"

  printf ${bold}
  _listFiles_ glob "waveapp*.csv" "./"
  printf ${reset}

  header "Finished"

  [[ "${keepworkingdir}" = false ]] && _safeDelete_ "${workingDataDir}" || info "Keeping working data directory (--keepworkingdir=${bold}${keepworkingdir}${reset})"

  printf ${blue}
  lolcat <<'EOF'

     _____________/\/\________/\/\__________________/\/\_____________________________
    ___/\/\/\/\__/\/\________________/\/\/\______/\/\/\/\/\____/\/\/\/\__/\/\__/\/\_ 
   _/\/\/\/\____/\/\/\/\____/\/\________/\/\______/\/\______/\/\/\/\____/\/\__/\/\_  
  _______/\/\__/\/\__/\/\__/\/\____/\/\/\/\______/\/\____________/\/\__/\/\__/\/\_   
 _/\/\/\/\____/\/\__/\/\__/\/\/\__/\/\/\/\/\____/\/\/\____/\/\/\/\______/\/\/\/\_    
________________________________________________________________________________     
                                                                         @choyer

EOF
  printf ${reset}

} # end _mainScript_


_showInvoices_() {
  # DESC:   Shows invoices in a nice way
  # ARGS:   N/A
  # OUTS:   Prints invoices to STDOUT
  # USAGE:  _showInvoices_

  # TODO: group by date, calculate invoice total, display in a nice manner.
  # for now this works
  _execute_ -v "xsv select \"Invoice Date\",\"Invoice Number\",\"Memo\",\"Customer Name\",\"Item Name\",\"Unit Price\" ./waveapp-invoice-import-data.csv \
                | xsv table"
}


_safeDelete_() {
  # DESC:   Deletes a file or directory safely. Use either glob or regex
  # ARGS:   $3 (Required) - directory
  # OUTS:   Prints deleted files/directories to STDOUT
  # USAGE:  _safeDelete_ "some/backup/dir"

  [[ $# -lt 1 ]] && {
    error 'Missing required argument to _safeDelete_()!'
    return 1
  }

  local d="${1:-.}"
  local fileMatch e

  # Error handling
  [ ! "$(declare -f "_execute_")" ] \
    && {
      warning "need function _execute_"
      return 1
    }

  case ${d} in
    /|/var|/etc|/home|/usr|/opt|/root) warning "Will NOT delete ${d}" ;;
    *) _execute_ -s "rm -rf \"${d}\"" ;;
  esac
}

_usage_() {
  cat <<EOF
  Conduit between ClinicSense CSV data + Paystone CSV data --> WaveApp Accounting

  ${bold}USAGE${reset}
    $(basename "$0") [OPTION(S)]...

  ${bold}OPTIONS${reset}
    -d, --data          Display shiatsu-data directory to shows past script executions and contents
    -h, --help          Display this help and exit
    -l, --loglevel      One of: FATAL, ERROR, WARN, INFO, DEBUG, ALL, OFF  (Default is 'ERROR')
    -n, --dryrun        Non-destructive. Makes no permanent changes
    -q, --quiet         Quiet (no output)
    -v, --verbose       Output more information. (Items echoed to 'verbose')

    --invoices          Show invoices from last script run.
    --clean             Delete all *.csv files in current directory
    --keepworkingdir    Keep working data directory. Default removes it.
    --delete            Delete and remove the entire 'shiatsu-data' directory
    --force             Skip all user interaction. Implied 'Yes' to all actions
    --version           Output version

  ${bold}DESCRIPTION${reset}
    • Validates ClinicSense & Paystone Batch CSV files
    • Merges/Matches ClinicSense & Paystone Batch CSV files
    • Reformats data types to match WaveApp Accounting data types
    • Generates Invoice/Customer/Service CSV files suitable for import into WaveApp Accounting
    • Imports generated data to WaveApp via GraphQL API (WIP)

    # Examples:

    # Set log level
    $(basename "$0") --loglevel 'WARN'

EOF
}

_parseOptions_() {
  # Iterate over options
  # breaking -ab into -a -b when needed and --foo=bar into --foo bar
  optstring=h
  unset options
  while (($#)); do
    case $1 in
      # If option is of type -ab
      -[!-]?*)
        # Loop over each character starting with the second
        for ((i = 1; i < ${#1}; i++)); do
          c=${1:i:1}
          options+=("-$c") # Add current char to options
          # If option takes a required argument, and it's not the last char make
          # the rest of the string its argument
          if [[ $optstring == *"$c:"* && ${1:i+1} ]]; then
            options+=("${1:i+1}")
            break
          fi
        done
        ;;
      # If option is of type --foo=bar
      --?*=*) options+=("${1%%=*}" "${1#*=}") ;;
      # add --endopts for --
      --) options+=(--endopts) ;;
      # Otherwise, nothing special
      *) options+=("$1") ;;
    esac
    shift
  done
  set -- "${options[@]}"
  unset options

  # Read the options and set stuff
  while [[ ${1-} == -?* ]]; do
    case $1 in
      -d | --data)
        ls ./shiatsu-data/*/
        _safeExit_
      ;;
      -h | --help)
        _usage_ >&2
        _safeExit_
        ;;
      -l | --loglevel)
        shift
        LOGLEVEL=${1}
        ;;
      -n | --dryrun) dryrun=true ;;
      -v | --verbose) verbose=true ;;
      -q | --quiet) quiet=true ;;
      --force) force=true ;;
      --invoices) 
        _showInvoices_
        _safeExit_
        ;;
      --version) 
        echo ${version} 
        _safeExit_ 
        ;;
      --endopts)
        shift
        break
        ;;
      --clean)
        _execute_ -s -v "rm -vf ./*.csv"
        _safeExit_ 
        ;;
      --delete)
        _seekConfirmation_ "Are you sure you want to DELETE all past data in (${baseDataDir})?" && _safeDelete_ "${baseDataDir}" || info "NO data removed!"
        _safeExit_ 
        ;;
      --keepworkingdir) keepworkingdir=true ;;
      *) die "invalid option: '$1'." ;;
    esac
    shift
  done
  args+=("$@") # Store the remaining user input as arguments.
}

# Initialize and run the script
trap '_trapCleanup_ $LINENO $BASH_LINENO "$BASH_COMMAND" "${FUNCNAME[*]}" "$0" "${BASH_SOURCE[0]}"' \
  EXIT INT TERM SIGINT SIGQUIT
set -o errtrace                           # Trap errors in subshells and functions
set -o errexit                            # Exit on error. Append '||true' if you expect an error
set -o pipefail                           # Use last non-zero exit code in a pipeline
# shopt -s nullglob globstar              # Make `for f in *.txt` work when `*.txt` matches zero files
IFS=$' \n\t'                              # Set IFS to preferred implementation
# set -o xtrace                           # Run in debug mode
set -o nounset                            # Disallow expansion of unset variables
# [[ $# -eq 0 ]] && _parseOptions_ "-h"   # Force arguments when invoking the script
_parseOptions_ "$@"                       # Parse arguments passed to script
# _makeTempDir_ "$(basename "$0")"        # Create a temp directory '$tmpDir'
# _acquireScriptLock_                     # Acquire script lock
_mainScript_                              # Run script
_safeExit_                                # Exit cleanly