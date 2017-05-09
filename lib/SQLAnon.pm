use Modern::Perl;
use Carp;
use autodie;
$Carp::Verbose = 'true'; #die with stack trace
use Try::Tiny;
use Scalar::Util qw(blessed);
use utf8;
binmode STDOUT, ":utf8";
binmode STDIN, ":utf8";

package SQLAnon;

# Copyright (C) 2017 Koha-Suomi
#
# This file is part of SQL Anonymizer.

use Memoize;
use Data::Dumper;
use Text::CSV;

use SQLAnon::AnonRules;
use SQLAnon::Lists;

use SQLAnon::Logger;
my $l = bless({}, 'SQLAnon::Logger');

=head1 SQLAnon

=head2 SYNOPSIS

MariaDB/MySQL mysqldump-tool SQL anonymizer

=cut

my $parser = Text::CSV->new( { binary => 1, quote_char => "'", escape_char => '\\', keep_meta_info => 1, allow_loose_escapes => 1, always_quote => 1 });

my $create_table_name;
my $column_number = 0;
my $column_name;
my $inside_create = 0;
my $insert_table_name;
my $inside_insert = 0;
my %table;
my %table_reverse;
my %column;
my %column_reverse;
my %contains_anon_column;
my %data_types;   #What data types are each column in each table? ...   table->columnNumber->?type?
my %column_sizes; #How many characters each column in each table can take? ...   table->columnNumber->?size?
my %quoted_types = map { $_ => 1 } qw( bit char datetime longtext text varchar );

#Tracks all the anonymized values for each table, insert-row and column. This is used afterwards to run automated tests against.
my %anonValStash; #$anonValStash{$tableName}[insertRowIndex]{$columnName} = $newValue;


sub init {
  SQLAnon::AnonRules::loadAnonymizationRules();
  SQLAnon::Lists::loadFakeNameLists();
  return 1;
}

sub anonymize {
  my ($fh) = @_;
  my $FH;
  my $c = SQLAnon::Config::getConfig();
  if (not($fh)) {
    $fh = $c->dbBackupFile;
  }
  if (ref($fh) ne 'GLOB') {
    my $filename = $fh;
    open($FH, "<:encoding(UTF-8)", $filename);
  }
  $FH = $fh unless $FH;

  while (<$FH>) {
    if ($inside_create == 1 && $_ =~ /ENGINE=(InnoDB|MyISAM)/) {
      $inside_create = 0; # create statement is finished
    }

    if ($inside_create == 0 && $_ =~ /^CREATE TABLE `([a-z0-9_]+)` \(/) {
      create_table($1);
    }

    if ($inside_create == 1 && $_ =~ /`([A-z0-9_]+)`\s([a-z]+)(?:\((\d+)\))?/ && $_ !~ /CREATE TABLE/) {
      inside_create($1, $2, $3); # parse create statement to index column positions
    }

    if($_ =~ /^(INSERT INTO `([a-z0-9_]+)` VALUES\s\()/) {
      inside_insert($1, $2); # anonymize VALUES statement
    }
    else {
      # this line won't be modified so just print it.
      print
    }

    if($inside_insert == 1 && $_ =~ /\);\n/) {
      $inside_insert = 0; # This insert is finished
    }
  }
  close($FH);
  return 1;
}

sub create_table {
  my $table = shift;
  $create_table_name = $table; #Store current table name
  $column_number = 0; # new create statement, reset column count
  $inside_create = 1;
}

sub inside_create {
  # process create statment to record ordinal position of columns
  my ($column, $type, $size) = @_;
  $size = _getColSize($type, $size);
  $column_name = $column;
  $table{$create_table_name}{$column_name} = $column_number;
  $table_reverse{$create_table_name}{$column_number} = $column_name;
  $data_types{$create_table_name}{$column_number} = $type;
  $column_sizes{$create_table_name}{$column_number} = $size;

  $l->debug("Analyzed table '$create_table_name', column '$column', type '$type', size '$size'");

  $column_number++;
}


sub inside_insert {
  my ($a1, $a2) = @_;
  $insert_table_name = $a2;
  my $start_of_string = $a1;
  $inside_insert = 1;
  if(SQLAnon::AnonRules::isTableAnonymizable($insert_table_name)) {
    # split insert statement
    my @lines = split('\),\(', $_);
    $lines[0] =~ s/\Q$start_of_string\E//g; # remove start of insert string, only interested in the "values"
    $lines[$#lines] =~ s/\);\n//g; # remove trailing bracket from last line of insert

    # loop through each line
    for (my $i=0 ; $i<scalar(@lines) ; $i++) {

      # use Text::CSV to parse the values
      my $status = $parser->parse($lines[$i]);
      my @columns = $parser->fields(); if($#columns == 0) { print $lines[$i], "\n"; die "\noops\n", $parser->error_input(); exit }

      # store quote status foreach column
      #my @quoted;
      #foreach my $index (0..$#columns) {
      #  push @quoted, $parser->is_quoted ($index);
      #}

      # replace selected columns with anon value
      map {
        my $collumn = getColumnNameByIndex($insert_table_name, $_); #$column and $column_name already conflict with global scope :(
        my $old_val = $columns[$_];
        $l->trace("Table '$insert_table_name', column '$collumn', old_val '$old_val'") if $l->is_trace;
        my $new_val = _dispatchValueFinder( $insert_table_name, $collumn, \@columns, $_ );
        if ($old_val ne 'NULL' ) { # only anonymize if not null

          $columns[$_] = _trimValToFitColumn($insert_table_name, $collumn, $old_val, $new_val);

          $l->debug("Table '$insert_table_name', column '$collumn', was '$old_val', is '$columns[$_]'") if $l->is_debug;
          pushToAnonValStash($insert_table_name, $i, $collumn, $columns[$_]);
        }
        else {
          $l->debug("Table '$insert_table_name', column '$collumn', is NULL") if $l->is_debug;
          pushToAnonValStash($insert_table_name, $i, $collumn, $columns[$_]);
        }
      } _get_anon_col_index($insert_table_name);

      # put quotes back
      foreach my $index (0..$#columns) {
  die " $insert_table_name $index " , Dumper(%data_types) if ! exists $data_types{$insert_table_name}{$index};
        if (exists $quoted_types{$data_types{$insert_table_name}{$index}} && $columns[$index] ne 'NULL') {

          # binary 1 & 0 mangled by Text::CSV, replace with unquoted 1 & 0
          my $bin_1 = quotemeta(chr(1));
          my $bin_0 = quotemeta(chr(0));
          if($columns[$index] =~ /$bin_1/) {
            $columns[$index] = 1; # if binary 1, set unquoted integer 1
          }
          elsif ($columns[$index] =~ /$bin_0/) {
             $columns[$index] = 0; # if binary 0, set unquoted integer 0
          }
          else {
            # use Text:CSV to add quotes - it will escape any quotes in the string
            $parser->combine( $columns[$index] );
            $columns[$index] =  $parser->string;
          }
        }
      }
      # put the columns back together
      $lines[$i] = join(',', @columns);
    }
    # reconstunct entire insert statement and print out
    print $start_of_string . join('),(', @lines) . ");\n";
  }
  else {
    print # print unmodifed insert
  }

}

=head2 _get_anon_col_index

@RETURNS an array of column ordinal postions for columns that are marked for anonymization

=cut

memoize('_get_anon_col_index');
sub _get_anon_col_index {
  my $table_name = shift;
  my @idx;
  foreach my $anonColumnName (@{SQLAnon::AnonRules::getAnonymizableColumnNames($table_name)}) {
    my $idx = getColumnIndexByName($table_name, $anonColumnName);
    if (defined($idx)) { #Defined is important because index can be 0
      push(@idx, $idx);
    }
    else {
      $l->warn("No such anonymizable column '$anonColumnName', for table '$table_name'. Do you have a typo in your anonymization configuration?");
    }
  }
  return sort {$a <=> $b} @idx;
}

=head2 _dispatchValueFinder

Find out how to get the anonymized value and get it

=cut

my $filterDispatcher = bless({}, 'SQLAnon::Filters');
sub _dispatchValueFinder {
  my ($tableName, $columnName, $columnValues, $index) = @_;
  my $rule = SQLAnon::AnonRules::getRule( $tableName, $columnName );
  $l->logdie("Anonymization rule not found for table '$tableName', column '$columnName'. We shouldn't even need to ask for it? Why does this happen?") unless $rule;

  my ($newVal, $dispatchType);
  if ($rule->{dispatch}) {
    $dispatchType = 'dispatch';
    my $closure = eval $rule->{ 'dispatch' };
    $newVal = $closure->();
    $l->logdie("In anonymization rule for table '$tableName', column '$columnName', when compiling custom code injection, got the following error:    $@") if $@;
  }
  elsif ($rule->{filter}) {
    $dispatchType = 'filter';
    my $filter = $rule->{filter};
    $newVal = $filterDispatcher->$filter($tableName, $columnName, $columnValues, $index);
  }
  elsif ($rule->{fakeNameList}) {
    $dispatchType = 'fakeNameList';
    $newVal = SQLAnon::Lists::get_value($rule->{fakeNameList}, $columnValues->[ $index ]);
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
  my $columnIndex = getColumnIndexByName($tableName, $columnName);

  my $maxSize = $column_sizes{$tableName}{$columnIndex};
  my $lengthOld = length($oldVal);
  if ($maxSize && $lengthOld <= $maxSize) {
    return $newVal;
  }
  return substr($newVal, 0, $lengthOld);
}

memoize('_getColSize');
sub _getColSize {
  my ($columnType, $size) = @_;
  return $size if $size;
  if (not($size)) { #Max size might not be explicitly known, so we can infer it from the data type
    if ($columnType =~ /text/) { #bigtext, mediumtext, text, ...
      $size = 1024;
    }
    elsif ($columnType eq 'date') {
      $size = 10;
    }
  }
  return $size;
}

=head2 getColumnNameByIndex

TODO: Table information should be refactored to it's own package

=cut

sub getColumnNameByIndex {
  my ($tableName, $colIndex) = @_;
  return $table_reverse{$tableName}{$colIndex};
}

=head2 getColumnIndexByName

TODO: Table information should be refactored to it's own package

=cut

sub getColumnIndexByName {
  my ($tableName, $colName) = @_;
  $l->logdie("\$colName '$colName' is not a SCALAR") if (ref($colName));
  return $table{$tableName}{$colName};
}

=head2 getColumnNames

@PARAM1 String, table name
@RETURNS ARRAYRef of Strings, The names of the columns of the given table in proper order

=cut

memoize('getColumnNames');
sub getColumnNames {
  my ($tableName) = @_;
  my @names;
  while ( my ($i, $name) = each %{$table_reverse{$tableName}}) {
    $names[$i] = $name;
  }
  return \@names;
}

=head pushToAnonValStash

Store the anonymized values to the stash so we can inspect what happened afterwards without resorting to reparsing the printed output.

=cut

sub pushToAnonValStash {
  my ($tableName, $insertRowIndex, $columnName, $val) = @_;
  $anonValStash{$tableName}[$insertRowIndex]{$columnName} = $val;
}
sub getAnonValStash {
  return \%anonValStash;
}

1;