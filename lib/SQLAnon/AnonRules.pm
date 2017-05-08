use Modern::Perl;
use utf8;
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

  my $lists = SQLAnon::Lists::getLists();

  open(my $fh, "<:encoding(UTF-8)", $anonymizationRulesFile);
  my $parser = Text::CSV->new( { binary => 1, allow_whitespace => 1 });
  while(my $row = $parser->getline($fh)) {
    next if (scalar(@$row) <= 1);
    $l->trace("Loading row ".$l->flatten($row)) if $l->is_trace;

    my ($table, $column, $type) = @$row;

    my $closure;
    if ($type =~ /^sub\s*\{.+\}$/) {
      $anon_columns{ $table }{ $column }{'dispatch'} = $type;
    }
    elsif ($type =~ /\(\)$/) { #Ends with () means uses a pre-existing filter
      $type = substr($type, 0, length($type)-2);
      _checkRuleFilter($table, $column, $type, $lists);
      $anon_columns{ $table }{ $column }{'filter'} = $type;
    }
    else {
      _checkRuleTypeFakeNameList($table, $column, $type, $lists);
      $anon_columns{ $table }{ $column }{'fakeNameList'} = $type;
    }
  }
  return \%anon_columns;
}

sub _checkRuleTypeFakeNameList {
  my ($table, $column, $type, $fakeNameLists) = @_;
  if (exists($fakeNameLists->{$type})) {
    #We got a matching "fake name list" == "type"
  }
  elsif ($type eq 'preserve') {    #Preserve these values
    #This is an allowed exception to the rule
  }
  else {
    die "Invalid fake name list '$type' in anonymization rules file's table '$table', column '$column'";
  }
}

my $filterDispatcher = bless({}, 'SQLAnon::Filters');
sub _checkRuleFilter {
  my ($table, $column, $type, $lists) = @_;
  die "Invalid filter '$type' in anonymization rules file's table '$table', column '$column'" unless ($filterDispatcher->can($type));
}

sub getRule {
  my ($table, $column) = @_;
  return $anon_columns{$table}{$column};
}

1;