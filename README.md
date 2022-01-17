# shiatsu-sh

## What is this?

A scripted means to associate exported [ClinicSense](https://clinicsense.com/) **appointment** and **payment** CSV data with [Paystone](https://www.paystone.com/) **batch** CSV data for the purpose of importing it into [Wave Accounting](https://www.waveapps.com/) using [Wave Connect](https://support.waveapps.com/hc/en-us/articles/360020768272-Wave-Connect-Easily-import-and-export-data-with-Wave-s-Google-Sheets-add-on-) via their officially supported [Google Sheets add-on](https://workspace.google.com/marketplace/app/wave_connect/90421189176). Patient info (e.g. their name) is anonymized when imported into Wave Accounting.

## Why?

It allows a ClinicSense practioner to match and merge a chosen period of appointments with payments received, including Paystone Batch data, and provide the data necesssary to create an invoice in Wave Accounting which ultimately allows one to reconcile bank account income.

It started as a small simple AWK script and grew into this monstrosity of a shell script combined with awk scripts held together by some dependancies, duct tape and bubblegum. It would be much better to do this in a "real programming language", but it works.


## Workflow

1. Within ClinicSense select *Reports* -> *Appointments*, choose date range from dropdown menu. Click *Generate Report* button.
2. Click gear icon -> *Download CSV* to save .csv file to local computer
3. Still within ClinicSense select *Reports* -> *Payments*, choose date range from dropdown menu. Click *Generate Report* button.
4. Click gear icon -> *Download CSV* to save .csv file to local computer
5. Within Paystone Hub select *Batches* -> *Filter*, choose date range and click apply
6. Select *Export* to save .csv file to local computer
7. Copy the 3 .csv files to the same directory containing the shiatsu2.sh script
8. Run the shiatsu2.sh script using `./shiatsu2.sh --verbose`
9. The verbose output is extremely detailed. It makes great bedtime reading.
10. Use the output files, namely `waveapp-invoice-import-data.csv` with a Wave Connect in Google Sheets.

Note: For expected results, the date range used for each of the 3 data files should be the same otherwise non-matching data will be discarded from the final merged data.

## Usage

With exported ClinicSense Appointment & Payment and Paystone Batch CSV files in the script root, run using: `./shiatsu2.sh --verbose`

When done with the output run: `./shiatsu2.sh --clean` to delete all working data **including original report csv files**.


`./shiatsu2.sh --help`

```bash
Conduit between ClinicSense CSV data + Paystone CSV data --> WaveApp Accounting

  USAGE
    shiatsu2.sh [OPTION(S)]...

  OPTIONS
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

  DESCRIPTION
    • Validates ClinicSense & Paystone Batch CSV files
    • Merges/Matches ClinicSense & Paystone Batch CSV files
    • Reformats data types to match WaveApp Accounting data types
    • Generates Invoice/Customer/Service CSV files suitable for import into WaveApp Accounting
    • Imports generated data to WaveApp via GraphQL API (WIP)

    # Examples:

    # Normal execution
    shiatsu2.sh --verbose

    # Clean-up after execution (e.g. delete all input/output files)
    shiatsu2.sh --clean

    # Set log level
    shiatsu2.sh --loglevel 'WARN'
```


## Dependancies

### GNU Awk (gawk)

GNU Awk is **required**. Default MacOS awk will throw errors with some of these awk scripts.

Install it on MacOS via homebrew `brew install gawk`

For a detailed look at using GNU Awk checkout the [The GNU Awk User’s Guide](https://www.gnu.org/software/gawk/manual/html_node/index.html).

### xsv

xsv is **required**.

Install it on MacOS via homebrew `brew install xsv`

xsv is a command line program for indexing, slicing, analyzing, splitting and joining CSV files. [more info & source](https://github.com/BurntSushi/xsv)

### lolcat

lolcat is **optional**, but maximum awesomeness is not achievable without it!!!

Install it on MacOS via homebrew `brew install lolcat`

lolcat makes text rainbows. [more info & source](https://github.com/busyloop/lolcat)


## Caveats

- There's a lot going on, this script is really only usable to someone really comfortable with bash and awk scripts.
- It's up to you how you want the invoice data imported into Wave. I would recommend using a 7 day period of appointments per invoice. This allows you to reconcile 1 week at a time. I have found weird things happen in Wave Accounting with invoices that contain too many line items (e.g. 100+ line items).
- There is some very customized data massaging going on, like creating line items for rounding adjustments.
- The entire process is still very much an exercise in manual labour. There is no ClinicSense API and the Wave API is *next level* GraphQL, so for now getting data out & in is entirely manual.
