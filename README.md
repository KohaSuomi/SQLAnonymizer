# DB Anonymizer

This script will anonymize a MySQL/MariaDB backup file created with mysqldump using the given rules.

This program can work as a stream processor, sitting between the backup operation and archiving/encrypting or read/write to static files.

It supports multiple levels of logging via the excellent Log::Log4perl, configurable from /etc/SQLAnon/log4perl.conf

See sqlanonymize -h for usage info and examples

## INSTALLATION

```shel
#Clone the repo
git clone https://github.com/KohaSuomi/SQLAnonymizer.git

#Build, test, install
cd SQLAnonymizer
perl Build.PL
perl Build test
sudo perl Build install

#Configure configs
nano /etc/SQLAnon/*

#Run the program
sqlanonymize
```

## Configuration

Configuration can be done from /etc/SQLAnon/SQLAnon.conf

## Anonymization rules

Anonymization rules by default are in /etc/SQLAnon/anonymizations.csv
The anonymization rules config file has three columns: table name, column name, anonymization style and optional comment section.
Add entry to the file for each column that needs anonymizing.
Valid anonymization styles are "fake name lists", "code injection", "filters".

#### Fake name lists

Fake name lists are .csv-files containing only rows of replacement values, see examples and valid values in fakeNameLists/
To use a fake name list, simply set the anonymization style -column as the name of the fake name list without the .csv-suffix.

Anon data is pulled from the CSV files, only 5000 entries are loaded, and it will loop through to beginning of the list when the 5000 have been used.

#### Code injection

You can do more complicated stuff by injecting perl code to be ran to anonymize a column.
To use code injection, set the anonymization style -column as an anonymous perl subroutine.
see config/anonymizations.csv for examples.

#### Filters

To use a predetermined filter, set the anonymization style -column to the filter name ending with parenthesis, eg. dateOfBirthAnonDayMonth()
You can find the allowed filters in lib/SQLAnon/Filters.pm
Each subroutine is a valid filter use.

## Limitations

Currently only works with lower case table names (simple change to the regex would fix that). Probably won't work if you have schema names(again, update the regex!).
Anonymised data might get truncated to the length of the original data to ensure the insert line doesn't exceed the mysql max allowed packet, if the column size cannot be detected.
May throw up the odd warning about invalid utf8 bytes. 

## Usage
```shell
sqlanonymize -h
```
