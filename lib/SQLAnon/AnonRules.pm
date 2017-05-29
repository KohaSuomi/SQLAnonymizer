use Modern::Perl;
#use utf8;
binmode STDOUT, ":utf8";
binmode STDERR, ":utf8";
use autodie;

package SQLAnon::AnonRules;

use Carp qw(longmess);
$Carp::Verbose = 'true'; #die with stack trace
use Try::Tiny;
use Scalar::Util qw(blessed);
use Params::Validate;

# Copyright (C) 2017 Koha-Suomi
#
# This file is part of SQL Anonymizer.

use Cwd;
use Text::CSV;

use SQLAnon::Config;
use SQLAnon::Lists;
use SQLAnon::Filters;
use SQLAnon::Logger;
my $l = bless({}, 'SQLAnon::Logger');

=head1 SQLAnon::AnonRules

=head2 SYNOPSIS

Module for loading all anonymization rules used to anonymize the SQL dump

=cut

my %anon_columns;

sub loadAnonymizationRules {
  my ($anonymizationRulesFile) = @_;
  my $c = SQLAnon::Config::getConfig();
  $anonymizationRulesFile = $c->anonymizationRulesFile unless ($anonymizationRulesFile);
  $l->debug("Loading anonymization rules from '$anonymizationRulesFile'");

  my $lists = SQLAnon::Lists::getFakeNameLists();
  #open(my $fh, "<:encoding(UTF-8)", $anonymizationRulesFile) or $l->logdie("Can't open anonymization rules file '$anonymizationRulesFile': $!");
  open(my $fh, "<:raw", $anonymizationRulesFile) or $l->logdie("Can't open anonymization rules file '$anonymizationRulesFile': $!");
  my $parser = Text::CSV->new( { binary => 1, allow_whitespace => 1 });
  while(my $row = $parser->getline($fh)) {
    next if (scalar(@$row) <= 1);
    $l->trace("Loading row ".$l->flatten($row)) if $l->is_trace;

    my ($tableName, $columnName, $type) = @$row;

    my $closure;
    if ($type =~ /^sub\s*\{.+\}$/) {
      $anon_columns{ $tableName }{ $columnName }{'dispatch'} = $type;
    }
    elsif ($type =~ /\(\)$/) { #Ends with () means uses a pre-existing filter
      $type = substr($type, 0, length($type)-2);
      _checkRuleFilter($tableName, $columnName, $type, $lists);
      $anon_columns{ $tableName }{ $columnName }{'filter'} = $type;
    }
    else {
      _checkRuleTypeFakeNameList($tableName, $columnName, $type, $lists);
      $anon_columns{ $tableName }{ $columnName }{'fakeNameList'} = $type;
    }
  }
  unless ($parser->eof) {
    $l->logdie("When parsing anonymization rules from '$anonymizationRulesFile', on row '".$parser->record_number()."' got the error:    ".$parser->error_diag()); #If we didn't reach end of file, throw an error
  }
  return \%anon_columns;
}

sub _checkRuleTypeFakeNameList {
  my ($table, $column, $type, $fakeNameLists) = @_;
  if (exists($fakeNameLists->{$type})) {
    #We got a matching "fake name list" == "type"
  }
  elsif ($type eq 'preserve' || $type eq '!KILL!') {    #Preserve these values
    #This is an allowed exception to the rule
  }
  else {
    $l->logdie("Invalid fake name list '$type' in anonymization rules file's table '$table', column '$column'");
  }
}

my $filterDispatcher = bless({}, 'SQLAnon::Filters');
sub _checkRuleFilter {
  my ($table, $column, $type, $lists) = @_;
  $l->logdie("Invalid filter '$type' in anonymization rules file's table '$table', column '$column'") unless ($filterDispatcher->can($type));
}

sub isTableAnonymizable {
  my ($tableName) = @_;
  return (exists $anon_columns{$tableName}) ? 1 : 0;
}

=head2 isKilled

=cut

sub isKilled {
  my ($tableName) = @_;
  return (exists $anon_columns{$tableName} && $anon_columns{$tableName}{'!KILL!'}) ? 1 : 0;
}

sub getAnonymizableColumnNames {
  my ($tableName) = @_;
  my @columnNames = keys %{$anon_columns{$tableName}};
  return \@columnNames;
}

sub getRule {
  my ($tableName, $columnName) = @_;
  return $anon_columns{$tableName}{$columnName};
}

1;