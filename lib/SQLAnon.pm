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

sub init {
  SQLAnon::AnonRules::loadAnonymizationRules();
  SQLAnon::Lists::loadFakeNameLists();
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
  $l->debug("Analyzing table '$create_table_name', column '$column', type '$type', size '".($size || 'undef')."'");
  $column_name = $column;
  if(SQLAnon::AnonRules::getRule($create_table_name, $column_name)) {
    $table{$create_table_name}{$column_name} = $column_number;
    $table_reverse{$create_table_name}{$column_number} = $column_name;
  }
  $data_types{$create_table_name}{$column_number} = $type;
  $column_sizes{$create_table_name}{$column_number} = $size || undef;
  $column_number++;
}


sub inside_insert {
  my ($a1, $a2) = @_;
  $insert_table_name = $a2;
  my $start_of_string = $a1;
  $inside_insert = 1;

  if(exists $table{$insert_table_name}) { # table contains anon candidate
    # split insert statement
    my @lines = split('\),\(', $_);
    $lines[0] =~ s/\Q$start_of_string\E//g; # remove start of insert string, only interested in the "values"
    $lines[$#lines] =~ s/\);\n//g; # remove trailing bracket from last line of insert

    # loop through each line
    foreach my $line (0..$#lines) {

      # use Text::CSV to parse the values
      my $status = $parser->parse($lines[$line]);
      my @columns = $parser->fields(); if($#columns == 0) { print $lines[$line], "\n"; die "\noops\n", $parser->error_input(); exit }

      # store quote status foreach column
      #my @quoted;
      #foreach my $index (0..$#columns) {
      #  push @quoted, $parser->is_quoted ($index);
      #}

      # replace selected columns with anon value
      map {
        my $collumn = $table_reverse{$insert_table_name }{$_}; #$column and $column_name already conflict with global scope :(
        my $old_val = $columns[$_];
        $l->trace("Table '$insert_table_name', column '$collumn', old_val '$old_val'") if $l->is_trace;
        my $new_val = _dispatchValueFinder( $insert_table_name, $collumn, $old_val );
        if ($old_val ne 'NULL' ) { # only anonymize if not null

          $columns[$_] = _trimValToFitColumn($insert_table_name, $collumn, $data_types{$insert_table_name}{$_}, $old_val, $new_val);

          $l->debug("Table '$insert_table_name', column '$collumn', was '$old_val', is '$columns[$_]'") if $l->is_debug;
        }
        else {
          $l->debug("Table '$insert_table_name', column '$collumn', is NULL") if $l->is_debug;
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
      $lines[$line] = join(',', @columns);
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
  foreach my $col (keys %{ $table{ $table_name } } ) {
    if (exists $table{$table_name}{$col}) {
      push @idx, $table{$table_name}{$col};
    }
  }
  return sort @idx;

}

=head2 _dispatchValueFinder

Find out how to get the anonymized value and get it

=cut

my $filterDispatcher = bless({}, 'SQLAnon::Filters');
sub _dispatchValueFinder {
  my ($tableName, $columnName, $val) = @_;
  my $rule = SQLAnon::AnonRules::getRule( $tableName, $columnName );
  $l->logdie("Anonymization rule not found for table '$tableName', column '$columnName'. We shouldn't even need to ask for it? Why does this happen?") unless $rule;

  my $newVal;
  if ($rule->{dispatch}) {
    my $closure = eval $rule->{ 'dispatch' };
    $newVal = $closure->();
    $l->logdie("In anonymization rule for table '$tableName', column '$columnName', when compiling custom code injection, got the following error:    $@") if $@;
  }
  elsif ($rule->{filter}) {
    my $filter = $rule->{filter};
    $newVal = $filterDispatcher->$filter($val);
  }
  elsif ($rule->{fakeNameList}) {
    $newVal = SQLAnon::Lists::get_value($rule->{fakeNameList});
  }
  else {
    $l->logdie("In anonymization rule for table '$tableName', column '$columnName', dont know how to get the anonymized value using rule '".$l->flatten($rule)."'");
  }
  return $newVal;
}

=head2 _trimValToFitColumn

Make sure the new anonymized value is not too large

=cut

memoize('_trimValToFitColumn');
sub _trimValToFitColumn {
  my ($tableName, $columnName, $columnType, $oldVal, $newVal) = @_;

  my $maxSize = $column_sizes{$tableName}{$columnName};
  if (not($maxSize)) { #Max size might not be explicitly known, so we can infer it from the data type
    if ($columnType =~ /text/) { #bigtext, mediumtext, text, ...
      $maxSize = 1024;
    }
    elsif ($columnType eq 'date') {
      $maxSize = 10;
    }
  }
  my $lengthOld = length($oldVal);
  if ($maxSize && $lengthOld <= $maxSize) {
    return $newVal;
  }
  return substr($newVal, 0, $lengthOld);
}

1;