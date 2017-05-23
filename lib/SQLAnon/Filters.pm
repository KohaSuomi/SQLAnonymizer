use Modern::Perl;
#use utf8;
binmode STDOUT, ":utf8";
binmode STDERR, ":utf8";
use autodie;

package SQLAnon::Filters;

use Carp qw(longmess);
$Carp::Verbose = 'true'; #die with stack trace
use Try::Tiny;
use Scalar::Util qw(blessed);
use Params::Validate;

# Copyright (C) 2017 Koha-Suomi
#
# This file is part of SQL Anonymizer.

use Cwd;
use Memoize;
use File::Basename;

use SQLAnon::Config;
use SQLAnon::Logger;
my $l = bless({}, 'SQLAnon::Logger');

=head1 SQLAnon::Filters

=head2 SYNOPSIS

These filters are called to anonymize individual column values

=head2 INTERFACE

All filters defined here must follow the same calling pattern:

@PARAM1 $class,       String, 'SQLAnon::Filters'
@PARAM2 $tableName,   String, the name of the table being filtered
@PARAM3 $columnName,  String, the name of the column being filtered
@PARAM4 $columnVals,  ARRAYRef of Strings, the values of the insert statement columns
@PARAM5 $colIndex,    Integer, The current index in the columns of the value being filtered
@RETURNS String, anonymized value to replace the old value in column index $colIndex

=cut


#Preserve year
sub dateOfBirthAnonDayMonth {
  my ($class, $tableName, $columnName, $columnVals, $colIndex) = @_;
  $columnVals->[ $colIndex ] =~ s/-\d\d-\d\d/-01-01/;
  return $columnVals->[ $colIndex ];
}

sub kohaSystempreferences {
  my ($class, $tableName, $columnName, $columnVals, $colIndex) = @_;

  ##Firstly get the variable
  my $variableI = SQLAnon::getColumnIndexByName($tableName, 'variable');
  $l->logdie("Filtering table '$tableName', column '$columnName', column 'variable' not found! variable-col is mandatory to know which syspref we are handling and what specific anonymization rules to apply.") unless defined($variableI);
  my $variable = $columnVals->[ $variableI ];
  $l->debug("Filtering table '$tableName', column '$columnName', variable='$variable'");

  if    ($variable eq 'VaaraAcqVendorConfigurations') {
    return "---\n\n"; #Return empty YAML
  }
  elsif ($variable eq 'AutoSelfCheckPass') {
    return "1234";
  }
=disable code
  elsif ($variable eq '') {
    
  }
  elsif ($variable eq '') {
    
  }
=cut
  else {
    return $columnVals->[ $colIndex ]; #No anonymization needed, return the old value
  }
}

=head2 addressWithSuffix

Takes an address from osoitteet.csv and suffixes it with random numbering information

=cut

sub addressWithSuffix {
  my ($class, $tableName, $columnName, $columnVals, $colIndex) = @_;

  my $adr = SQLAnon::Lists::get_value('osoitteet');
  my $r= int(rand(100));
  my $suffix;
  if    ($r <= 50) {
    $suffix = int(rand(100));
  }
  elsif ($r <= 75) {
    $suffix = int(rand(100)) . ' ' . uc(sprintf("%c", 65+rand(25)));
  }
  elsif ($r <= 100) {
    $suffix = int(rand(100)) . ' ' . uc(sprintf("%c", 65+rand(25))) . ' ' . int(rand(100));
  }
  return join(' ',$adr,$suffix);
}

1;