use Modern::Perl;
use Carp;
use autodie;
$Carp::Verbose = 'true'; #die with stack trace
use Try::Tiny;
use Scalar::Util qw(blessed);
#use utf8; #See. head3 UTF-8 handling
binmode STDOUT, ":utf8";
binmode STDERR, ":utf8";
#binmode STDIN, ":utf8"; #See. head3 UTF-8 handling

package SQLAnon;

# Copyright (C) 2017 Koha-Suomi
#
# This file is part of SQL Anonymizer.

use Memoize;
use Data::Dumper;
use Text::CSV;
use MySQL::Dump::Parser::XS;

use SQLAnon::AnonRules;
use SQLAnon::Lists;

use SQLAnon::Logger;
my $l = bless({}, 'SQLAnon::Logger');

=head1 SQLAnon

=head2 SYNOPSIS

MariaDB/MySQL mysqldump-tool SQL anonymizer

=head3 UTF-8 handling

Since the DB dump can/will contain binary data, and encoding/decoding binary data which is not supposed to be UTF-8, can damage it,
work with input/output in :raw-encoding

=cut

my $parser = MySQL::Dump::Parser::XS->new;

my $IN; #Input stream
my $OUT; #Output stream

#Tracks all the anonymized values for each table, insert-row and column. This is used afterwards to run automated tests against.
my %anonValStash; #$anonValStash{$tableName}[insertRowIndex]{$columnName} = $newValue;


sub init {
  SQLAnon::AnonRules::loadAnonymizationRules();
  SQLAnon::Lists::loadFakeNameLists();
  return 1;
}

my $inside_insert_regexp = qr/^(INSERT INTO `([a-z0-9_]+)` VALUES\s\()/;
sub anonymize {
  my ($inputStream, $outputStream) = @_;
  ($IN, $OUT) = getIOHandles($inputStream, $outputStream);

  my $prevTable = 'undef';
  while (my $line = <$IN>) {
    $line =~ s/\\/\\\\/g; #MySQL::Dump::Parser::XS loses backslashes so we duplicate them
    my $anonLine; #The $line after anonymization
    my @rows  = $parser->parse($line);
    if (@rows) {
      $l->logdie("Got a bunch of \@rows but no table name, on line $. after table '$prevTable'") unless ($parser->current_target_table());
      my $tableName = $parser->current_target_table();
      $prevTable = $tableName;
      if ($line =~ $inside_insert_regexp) {
        my $insertPrefix = $1;
        my $tableName2 = $2;
        $l->logdie("Parsed table names '$tableName' and '$tableName2' are different???, on line $. after table '$prevTable'") unless ($tableName eq $tableName2);
        $anonLine = anonymizeTable($insertPrefix, $tableName, \@rows);
      }
      else {
        $l->logdie("Cannot parse INSERT prefix, on line $. table '$tableName'");
      }
    }
    print $OUT ($anonLine) ? $anonLine : $line;
  }

  close($IN) if ($IN ne *STDIN);
  close($OUT) if ($OUT ne *STDOUT);

  return 1;
}

sub anonymizeTable {
  my ($insertPrefix, $tableName, $rows) = @_;
  if(SQLAnon::AnonRules::isTableAnonymizable($tableName)) {

    # loop through each value group
    for (my $i=0 ; $i<scalar(@$rows) ; $i++) {
      my $row = $rows->[$i];
      # replace selected columns with anon value
      my ($kill);
      map {
        my $columnName = $_;
        my $old_val = $row->{$columnName};
        $l->logdie("Table '$tableName', column '$columnName' is undefined. Trying to anonymize a column which doesn't exist!") unless(defined($old_val));
        $l->trace("Table '$tableName', column '$columnName', old_val '$old_val'") if $l->is_trace;
        my $new_val = _dispatchValueFinder( $tableName, $columnName, $row);

        if ($new_val eq '!KILL!') {
          $l->debug("Table '$tableName', column '$columnName', was '$old_val', now is !KILL!:ed") if $l->is_debug;
          pushToAnonValStash($tableName, $i, $columnName, $new_val);
          $kill = 1; #Instruct this value group to be removed from the DB dump
        }
        elsif ($old_val ne 'NULL' ) { # only anonymize if not null

          $row->{$columnName} = _trimValToFitColumn($tableName, $columnName, $old_val, $new_val);

          $l->debug("Table '$tableName', column '$columnName', was '$old_val', is '".$row->{$columnName}."'") if $l->is_debug;
          pushToAnonValStash($tableName, $i, $columnName, $row->{$columnName});
        }
        else {
          $l->debug("Table '$tableName', column '$columnName', is NULL") if $l->is_debug;
          pushToAnonValStash($tableName, $i, $columnName, $row->{$columnName});
        }
      } @{SQLAnon::AnonRules::getAnonymizableColumnNames($tableName)};

      if (not($kill)) {
        $rows->[$i] = recomposeValueGroup($tableName, $row);
      }
      else {
        $rows->[$i] = undef;
      }
    }
    # reconstunct entire insert statement and print out
    print $OUT recomposeInsertStatement($insertPrefix, $rows);
  }
  else {
    print $OUT $_; # print unmodifed insert
  }

}

=head2 recomposeInsertStatement

=cut

sub recomposeInsertStatement {
  my ($insertPrefix, $valueStrings) = @_;

  my @v = grep {defined($_)} @$valueStrings; #remove ☯KILL:ed values

  return $insertPrefix . join('),(', @v) . ");\n";
}

sub recomposeValueGroup {
  my ($tableName, $columns, $metas) = @_;

  #my $status = $parser->combine(@$columns);    # combine columns into a string
  #my $line   = $parser->string();              # get the combined string
  #unless($line) {
  #  $l->logdie("Error combining columns '@$columns', got Text::CSV status='$status' error: ".$parser->error_input());
  #}
  #return $line;

  # put quotes back
  for (my $i=0 ; $i<scalar(@$columns) ; $i++) {
    if ($metas->[$i] & 0x0001) { #If the 1st bit is on, then this column was quoted

      # binary 1 & 0 mangled by Text::CSV, replace with unquoted 1 & 0
      #my $bin_1 = quotemeta(chr(1));
      #my $bin_0 = quotemeta(chr(0));
      #if($columns->[$i] =~ /$bin_1/) {
      #  $columns->[$i] = 1; # if binary 1, set unquoted integer 1
      #}
      #elsif ($columns->[$i] =~ /$bin_0/) {
      #   $columns->[$i] = 0; # if binary 0, set unquoted integer 0
      #}
      #else {
        # use Text:CSV to add quotes - it will escape any quotes in the string
        $parser->combine( $columns->[$i] );
        $columns->[$i] =  $parser->string;
      #}
      $l->trace("Quoted table '$tableName', column '".getColumnNameByIndex($tableName, $i)."' value '".$columns->[$i]."'") if $l->is_trace;
    }
  }
  # put the columns back together
  return join(',', @$columns);
}

=head2 _dispatchValueFinder

Find out how to get the anonymized value and get it

=cut

my $filterDispatcher = bless({}, 'SQLAnon::Filters');
sub _dispatchValueFinder {
  my ($tableName, $columnName, $columnValues) = @_;
  my $oldVal = $columnValues->{$columnName};
  my $rule = SQLAnon::AnonRules::getRule( $tableName, $columnName );

  my ($newVal, $dispatchType);
  if ($rule->{dispatch}) {
    $dispatchType = 'dispatch';
    my $closure = eval $rule->{ 'dispatch' };
    $newVal = $closure->(@_);
    $l->logdie("In anonymization rule for table '$tableName', column '$columnName', when compiling custom code injection, got the following error:    $@") if $@;
  }
  elsif ($rule->{filter}) {
    $dispatchType = 'filter';
    my $filter = $rule->{filter};
    $newVal = $filterDispatcher->$filter($tableName, $columnName, $columnValues);
  }
  elsif ($rule->{fakeNameList}) {
    $dispatchType = 'fakeNameList';
    $newVal = SQLAnon::Lists::get_value($rule->{fakeNameList}, $columnValues->{ $columnName });
  }
  else {
    $l->logdie("In anonymization rule for table '$tableName', column '$columnName', dont know how to get the anonymized value using rule '".$l->flatten($rule)."'");
  }
  $l->debug("Dispatched table '$tableName', column '$columnName' via '$dispatchType', returning '$newVal'");
  return $newVal;
}

=head2 _trimValToFitColumn

Make sure the new anonymized value is not too large

=cut

sub _trimValToFitColumn {
  my ($tableName, $columnName, $oldVal, $newVal) = @_;
  my $maxSize = SQLAnon::AnonRules::getMaxSize( $tableName, $columnName );
  return substr($newVal, 0, $maxSize);
}

=head pushToAnonValStash

Store the anonymized values to the stash so we can inspect what happened afterwards without resorting to reparsing the printed output.

=cut

sub pushToAnonValStash {
  return undef unless($ENV{SQLAnonMODE} && $ENV{SQLAnonMODE} eq 'testing');
  my ($tableName, $insertRowIndex, $columnName, $val) = @_;
  $anonValStash{$tableName}[$insertRowIndex]{$columnName} = $val;
}
sub getAnonValStash {
  return \%anonValStash;
}

=head2 getIOHandles

Based on the cli and config arguments, we figure out which file/stream we read and write to

=cut

sub getIOHandles {
  my ($inputStream, $outputStream) = @_;
  my ($IN, $OUT);
  my $c = SQLAnon::Config::getConfig();

  if (not($inputStream)) {
    $inputStream = $c->dbBackupFile;
  }
  if ($inputStream ne '-') {
    #open($IN, "<:encoding(UTF-8)", $inputStream) or $l->logdie("Can't open input stream '$inputStream': $!");
    open($IN, "<:raw", $inputStream) or $l->logdie("Can't open input stream '$inputStream': $!");
  }
  else {
    $IN = *STDIN;
  }
  if (not($outputStream)) {
    $outputStream = $c->outputFile;
  }
  if ($outputStream ne '-') {
    #open($OUT, ">:encoding(UTF-8)", $outputStream) or $l->logdie("Can't open output stream '$outputStream': $!");
    open($OUT, ">:raw", $outputStream) or $l->logdie("Can't open output stream '$outputStream': $!");
  }
  else {
    $OUT = *STDOUT;
  }
  return ($IN, $OUT);
}

1;
