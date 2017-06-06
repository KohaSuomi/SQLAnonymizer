use Modern::Perl;
use Carp;
use autodie;
$Carp::Verbose = 'true'; #die with stack trace
use Try::Tiny;
use Scalar::Util qw(blessed);
#use utf8; #See. head3 UTF-8 handling
#binmode STDOUT, ":utf8";
#binmode STDERR, ":utf8";
#binmode STDIN, ":utf8"; #See. head3 UTF-8 handling

package SQLAnon;

# Copyright (C) 2017 Koha-Suomi
#
# This file is part of SQL Anonymizer.

use Memoize;
use Data::Dumper;
use Text::CSV;
use Text::ParseWords;

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

my $parser = Text::CSV->new( { binary => 1, quote_char => "'", escape_char => '\\', keep_meta_info => 1, allow_loose_escapes => 1, always_quote => 1 });

my $IN; #Input stream
my $OUT; #Output stream

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
my %column_constraints; #Any UNIQUE constrainsts? ... ->{"$tableName-$columnName-$constraintName"} = 1

#Tracks all the anonymized values for each table, insert-row and column. This is used afterwards to run automated tests against.
my %anonValStash; #$anonValStash{$tableName}[insertRowIndex]{$columnName} = $newValue;


sub init {
  my ($anonymizationRulesFile, $fakeNameListsDir) = @_;
  SQLAnon::AnonRules::loadAnonymizationRules($anonymizationRulesFile);
  SQLAnon::Lists::loadFakeNameLists($fakeNameListsDir);
  return 1;
}

my $inside_insert_regexp = qr/^(INSERT INTO `([a-z0-9_]+)` VALUES\s\()/;
sub anonymize {
  my ($inputStream, $outputStream) = @_;
  ($IN, $OUT) = getIOHandles($inputStream, $outputStream);

  while (<$IN>) {
    if ($inside_create == 1 && $_ =~ /^\) ENGINE=(InnoDB|MyISAM)/) {
      $inside_create = 0; # create statement is finished
    }
    elsif ($inside_create == 1 && $_ =~ /^  `([A-z0-9_]+)`\s([a-z]+)(?:\((\d+)\))?/) {
      inside_create($1, $2, $3); # parse create statement to index column positions
    }
    elsif ($inside_create == 1) {
      if (my @matches = $_ =~ /^  (UNIQUE|PRIMARY) KEY `([A-z0-9_]+)`\s\((`[A-z0-9_]+`,?)+\)/) {
        insideConstraint($create_table_name, @matches);
      }
    }
    elsif ($inside_create == 0 && $_ =~ /^CREATE TABLE `([a-z0-9_]+)` \(/) {
      create_table($1);
    }

    if($_ =~ $inside_insert_regexp) {
      inside_insert($1, $2); # anonymize VALUES statement
    }
    else {
      # this line won't be modified so just print it.
      print $OUT $_;
    }

    if($inside_insert == 1 && $_ =~ /\);\n/) {
      $inside_insert = 0; # This insert is finished
    }
  }

  close($IN) if ($IN ne *STDIN);
  close($OUT) if ($OUT ne *STDOUT);

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
  $l->warn("Unknown size for table '$create_table_name' column '$column'") if (not($size) && $l->is_warn());
  $column_name = $column;
  $table{$create_table_name}{$column_name} = $column_number;
  $table_reverse{$create_table_name}{$column_number} = $column_name;
  $data_types{$create_table_name}{$column_number} = $type;
  $column_sizes{$create_table_name}{$column_number} = $size;

  $l->debug("Analyzed table '$create_table_name', column '$column', type '$type', size '$size'") if $l->is_debug;

  $column_number++;
}

=head2 insideConstraint

Extract table constraints. One column can have multiple constraints

=cut

sub insideConstraint {
  my ($tableName, $constraint, $indexName, @columnNames) = @_;

  foreach my $cn (@columnNames) {
    $cn =~ s/`//g;
    $l->debug("Analyzed table '$tableName', column '$cn', constraint '$constraint'") if $l->is_debug;
    $column_constraints{"$tableName-$cn-$constraint"} = 1;
  }
}

sub inside_insert {
  my ($a1, $a2) = @_;
  $insert_table_name = $a2;
  my $start_of_string = $a1;
  $inside_insert = 1;
  if(SQLAnon::AnonRules::isTableAnonymizable($insert_table_name)) {
    if (SQLAnon::AnonRules::isKilled($insert_table_name)) {
      $l->trace("Dropping data for table '$insert_table_name'") if $l->is_trace;
      return undef;
    }

    my ($insert_table_name, $start_of_string, $lines) = decomposeInsertStatement($_);

    # loop through each line
    for (my $i=0 ; $i<scalar(@$lines) ; $i++) {

      my ($columns, $metaInfos) = decomposeValueGroup($lines->[$i]);

      # replace selected columns with anon value
      my ($kill);
      map {
        my $collumn = getColumnNameByIndex($insert_table_name, $_); #$column and $column_name already conflict with global scope :(
        my $old_val = $columns->[$_];
        $l->trace("Table '$insert_table_name', column '$collumn', old_val '$old_val'") if $l->is_trace;
        my $new_val = _dispatchValueFinder( $insert_table_name, $collumn, $columns, $_ );

        if ($new_val eq '!KILL!') {
          $l->debug("Table '$insert_table_name', column '$collumn', was '$old_val', now is ☯KILL:ed") if $l->is_debug;
          pushToAnonValStash($insert_table_name, $i, $collumn, $new_val);
          $kill = 1; #Instruct this value group to be removed from the DB dump
        }
        elsif ($old_val ne 'NULL' ) { # only anonymize if not null

          $columns->[$_] = _trimValToFitColumn($insert_table_name, $collumn, $old_val, $new_val);

          $l->debug("Table '$insert_table_name', column '$collumn', was '$old_val', is '$columns->[$_]'") if $l->is_debug;
          pushToAnonValStash($insert_table_name, $i, $collumn, $columns->[$_]);
        }
        else {
          $l->debug("Table '$insert_table_name', column '$collumn', is NULL") if $l->is_debug;
          pushToAnonValStash($insert_table_name, $i, $collumn, $columns->[$_]);
        }
      } _get_anon_col_index($insert_table_name);

      if (not($kill)) {
        $lines->[$i] = recomposeValueGroup($insert_table_name, $columns, $metaInfos);
      }
      else {
        $lines->[$i] = undef;
      }
    }
    # reconstunct entire insert statement and print out
    print $OUT recomposeInsertStatement($start_of_string, $lines);
  }
  else {
    print $OUT $_; # print unmodifed insert
  }

}

=head2 decomposeInsertStatement

Splits a INSERT statement to a list of individual VALUE-groups and the prefixing INSERT stanzas

You can recomposeInsertStatement() using these same @RETURN values.

@PARAM1 String, the complete INSERT statement with VALUES and all.
@RETURNS LIST of [0] = String, the table name
                 [1] = String, the start of the INSERT statement without VALUE-groups
                 [2] = ARRAYRef of VALUE-groups

=cut

sub decomposeInsertStatement {
  my ($insertStatement) = @_;

  if($insertStatement =~ $inside_insert_regexp) {
    my $insertPrefix = $1;
    my $tableName = $2;
    # split insert statement
    my @lines = Text::ParseWords::parse_line('\)\s*,\s*\(', 1, $insertStatement);
    $lines[0] =~ s/\Q$insertPrefix\E//; # remove start of insert string
    $lines[$#lines] =~ s/\);\n?//; # remove trailing bracket from last line of insert
    return ($tableName, $insertPrefix, \@lines);
  }
  else {
    $l->logdie("On DB dump line '$.', couldn't parse INSERT statement '$insertStatement'");
  }
}

=head2 recomposeInsertStatement

=cut

sub recomposeInsertStatement {
  my ($insertPrefix, $valueStrings) = @_;

  my @v = grep {defined($_)} @$valueStrings; #remove ☯KILL:ed values

  return $insertPrefix . join('),(', @v) . ");\n";
}

=head2 decomposeValueGroup

Splits a VALUE-group from a INSERT statement to a list of individual column values

You can recomposeValuegroup() using these same @RETURN values.

@PARAM1 String, the complete VALUE-group stanza
@RETURNS List of [0] = ARRAYRef of column values
                 [1] = ARRAYRef of column metainfo flags (see. http://search.cpan.org/~makamaka/Text-CSV-1.33/lib/Text/CSV.pm#meta_info)

=cut

sub decomposeValueGroup {
  my ($valueString) = @_;

  # use Text::CSV to parse the values
  my $status = $parser->parse($valueString);
  my @columns = $parser->fields();
  if($#columns == 0) {
    $l->logdie("Error parsing .csv-line '$valueString' got Text::CSV status='$status' error: ".$parser->error_input());
  }
  my @meta = $parser->meta_info();
  return (\@columns, \@meta);
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

my %uniqueDeduplicationTracker; #Track unique values for each table and column if column has unique-constraint
my $filterDispatcher = bless({}, 'SQLAnon::Filters');
sub _dispatchValueFinder {
  my ($tableName, $columnName, $columnValues, $index) = @_;
  my $oldVal = $columnValues->[$index];
  my $rule = SQLAnon::AnonRules::getRule( $tableName, $columnName );
  my $isUnique = _isUnique($tableName, $columnName);
  $l->logdie("Anonymization rule not found for table '$tableName', column '$columnName'. We shouldn't even need to ask for it? Why does this happen?") unless $rule;

  my ($newVal, $dispatchType);
  my $loops = 0;
  while (1) { #Keep retrying if the unique value is already reserved for this table and column
    #Start dispatching
    if ($oldVal eq 'NULL') {
      $newVal = $oldVal;
      $dispatchType = 'NULLer';
    }
    elsif ($rule->{dispatch}) {
      $dispatchType = 'dispatch';
      my $closure = eval $rule->{ 'dispatch' };
      $newVal = $closure->(@_);
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

    #Done dispatching, time to reap rewards
    $loops++;
    if ($isUnique && $uniqueDeduplicationTracker{"$tableName-$columnName-$newVal"} && $newVal ne 'NULL') {
      $l->info("Dispatched table '$tableName', column '$columnName' UNIQUE constraint failed for '$newVal', retry loop '$loops'") if $l->is_info();
      $l->logdie("Finding a suitable UNIQUE value '$newVal', for table '$tableName', column '$columnName', ended up in an endless loop!") if $loops > 10;
    }
    else {
      last; #Break away if we have a confirmedly unique value, or if we dont care
    }
  }
  $uniqueDeduplicationTracker{"$tableName-$columnName-$newVal"} = 1 if $isUnique;

  $l->debug("Dispatched table '$tableName', column '$columnName' via '$dispatchType', returning '$newVal'") if $l->is_debug;
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
    if ($columnType =~ /(?:text|blob)/) { #bigtext, mediumtext, text, blob, ...
      $size = 1024;
    }
    elsif ($columnType eq 'date') {
      $size = 10;
    }
    elsif ($columnType eq 'timestamp') {
      $size = 24;
    }
    elsif ($columnType eq 'datetime') {
      $size = 24;
    }
    elsif ($columnType eq 'enum') {
      $size = 1024;
    }
    elsif ($columnType eq 'decimal') {
      $size = 1024;
    }
    elsif ($columnType eq 'float') {
      $size = 1024;
    }
    elsif ($columnType eq 'double') {
      $size = 1024;
    }
  }
  return $size;
}

sub _isUnique {
  my ($tableName, $columnName) = @_;
  return $column_constraints{"$tableName-$columnName-UNIQUE"};
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
    open($IN, "<", $inputStream) or $l->logdie("Can't open input stream '$inputStream': $!");
  }
  else {
    $IN = *STDIN;
  }
  if (not($outputStream)) {
    $outputStream = $c->outputFile;
  }
  if ($outputStream ne '-') {
    #open($OUT, ">:encoding(UTF-8)", $outputStream) or $l->logdie("Can't open output stream '$outputStream': $!");
    open($OUT, ">", $outputStream) or $l->logdie("Can't open output stream '$outputStream': $!");
  }
  else {
    $OUT = *STDOUT;
  }
  return ($IN, $OUT);
}

1;