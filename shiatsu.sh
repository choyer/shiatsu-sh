#!/bin/bash
#
# ## shiatsu.sh ##
#
# A script to massage exported data from ClinicSense (https://clinicsense.com) 
# and Paystone Hub (https://hub.paystone.com) for the purpose of importing 
# as invoice data into the Wave Accounting App (https://www.waveapps.com).
#
# Copyright 2021 Carl Hoyer
#
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program.  If not, see <http://www.gnu.org/licenses/>.

OIFS="$IFS"
IFS=$'\n'

command_exists() {
	command -v "$@" >/dev/null 2>&1
}

fmt_error() {
  printf '%sError: %s%s\n' "$BOLD$RED" "$*" "$RESET" >&2
}

fmt_underline() {
  printf '\033[4m%s\033[24m\n' "$*"
}

fmt_code() {
  # shellcheck disable=SC2016 # backtic in single-quote
  printf '`\033[38;5;247m%s%s`\n' "$*" "$RESET"
}

setup_color() {
	# Only use colors if connected to a terminal
	if [ -t 1 ]; then
		RED=$(printf '\033[31m')
		GREEN=$(printf '\033[32m')
		YELLOW=$(printf '\033[33m')
		BLUE=$(printf '\033[34m')
		BOLD=$(printf '\033[1m')
		RESET=$(printf '\033[m')
	else
		RED=""
		GREEN=""
		YELLOW=""
		BLUE=""
		BOLD=""
		RESET=""
	fi
}


main() {

	setup_color

	# Check to see if gawk is installed
	(_checkBinary_ gawk ) && success("gawk installed") || error("gawk not found. Please install.")


	# Check to see if xsv is installed
	(_checkBinary_ xsv ) && success("xsv installed") || error("xsv not found. Please install.")

	printf %s "$GREEN"
  	cat <<'EOF'
         __    _       __            
   _____/ /_  (_)___ _/ /________  __
  / ___/ __ \/ / __ `/ __/ ___/ / / /
 (__  ) / / / / /_/ / /_(__  ) /_/ / 
/____/_/ /_/_/\__,_/\__/____/\__,_/
     massaging data like it's 1984


EOF
	printf %s "$RESET"

	time_stamp=$(date +%Y%m%d%H%M%S)

	datapath="./data"
	datadir="${datapath}/${time_stamp}"

	[ -d $datadir ] && echo "Directory exists: $datadir" || echo "Directory DOES NOT exist. Creating: $datadir" && mkdir -p $datadir

	find . -maxdepth 1 -type f -name "*.csv" -print0 | while IFS= read -r -d '' file; do
	    echo "File: [$file]"
	    l=`sed '/[^[:blank:]]/q;d' $file`
	    line=${l%%,*}
	    echo "First Line: [$line]"

	    case "$line" in
	    	"MID")
				type="paystone"
				cp $file "$datadir/$type-data.csv"

				gawk -v dateformat="%b %d, %Y" -v batchonly=true -f paystone-batch.awk "$datadir/$type-data.csv" > "$datadir/$type-batchonly.csv"
			;;
			"Revenue Report")
				type="revenue"
				# For the time being this report is not used and ignored.
			;;
			"Payments Report")
				type="payment"

				xsv slice --no-headers --end 9 --output "$datadir/$type-header.csv" $file
				xsv slice --no-headers --start 9 --output "$datadir/$type-data.csv" $file

				xsv index "$datadir/$type-data.csv"
			;;
			"Appointment Report")
				type="appointment"
				xsv slice --no-headers --end 7 --output "$datadir/$type-header.csv" $file
				xsv slice --no-headers --start 7 --output "$datadir/$type-data.csv" $file

				xsv index "$datadir/$type-data.csv"
			;;
		esac

		echo "Data type: [$type]"

	    read line </dev/tty
	done


	# After the individual report data is formatted start joining data

	# Join ClinicSense Appointment & Payment data WHERE NOT canceled
	echo "[Joining ClinicSense APPOINTMENT & PAYMENT data ...]"
		xsv join --no-case Date,Client "$datadir/appointment-data.csv" Date,Client "$datadir/payment-data.csv" | xsv select 'Date[1],Client[1],Practitioner,Primary Service,Reference Number,Payment Method,Amount' | xsv search '\[(Canceled)\]' --invert-match > "$datadir/clinicsense-joined-data.csv"
	echo "DONE"

	# Join ClinicSense Data with Paystone data to associate batch # to each ClinicSense record
	echo "[Joining ClinicSense & Paystone data ...]"
		xsv join --left --no-case Date "$datadir/clinicsense-joined-data.csv" 'Settlement Date' "$datadir/paystone-batchonly.csv" | xsv select 'Date,Client,Practitioner,Primary Service,Reference Number,Payment Method,Amount,Batch No.' > "$datadir/clincsense-paystone-data.csv"
	echo "DONE"

	# Calculate tax amounts
	echo "[Calculating Tax ...]"
		gawk -f clinicsense-tax.awk "$datadir/clincsense-paystone-data.csv" > "$datadir/service-transaction-data.csv"
	echo "DONE"

	# Final pass over data to format it just right
	echo "[Formating Field Formats just right ...]"
		gawk -f clinicsense-field-format.awk "$datadir/service-transaction-data.csv" > "$datadir/clinicsense-final-data.csv"
	echo "DONE"

	#
	echo "[WaveApp: Generate Invoice Import Data ...]"
		gawk -f waveapp-invoice-field-format.awk "$datadir/clinicsense-final-data.csv" > "$datadir/waveapp-invoice-import-data.csv"
	echo "DONE"


	# Generate Service List
	echo "[WaveApp: Generating Service Import Data ...]"
		xsv search -s "Item Name" '.*' "$datadir/waveapp-invoice-import-data.csv" | xsv select "Item Name" | sort --unique > "$datadir/waveapp-service-import-data.csv"
	echo "DONE"


	# Create Customer List
	echo "[WaveApp: Generating Customer Import Data ...]"
		xsv search -s "Customer Name" '.*' "$datadir/waveapp-invoice-import-data.csv" | xsv select "Customer Name" | sort --unique > "$datadir/waveapp-customer-import-data.csv"
	echo "DONE"


# 	cat <<'EOF'
# 	 _____________/\/\________/\/\__________________/\/\_____________________________
#     ___/\/\/\/\__/\/\________________/\/\/\______/\/\/\/\/\____/\/\/\/\__/\/\__/\/\_ 
#    _/\/\/\/\____/\/\/\/\____/\/\________/\/\______/\/\______/\/\/\/\____/\/\__/\/\_  
#   _______/\/\__/\/\__/\/\__/\/\____/\/\/\/\______/\/\____________/\/\__/\/\__/\/\_   
#  _/\/\/\/\____/\/\__/\/\__/\/\/\__/\/\/\/\/\____/\/\/\____/\/\/\/\______/\/\/\/\_    
# ________________________________________________________________________________     

# EOF

}

main "$@"