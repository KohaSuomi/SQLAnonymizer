use Modern::Perl;
use utf8;
binmode STDOUT, ":utf8";
binmode STDERR, ":utf8";
use autodie;

package SQLAnon::Lists;

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

=head1 SQLAnon::Lists

=head2 SYNOPSIS

Loads and accesses anonymizer fake name lists

=cut

my %anon_data;
my %seen; #Track anonymized random strings, so same strings are anonymized using the same random word

sub loadFakeNameLists {
  $l->debug("Loading anonymized lists");
  # load in the anon data
  my $lists = getLists();

  foreach my $key (sort keys %$lists) {
    $l->trace("Loading $key");
    open(my $fh, "<:encoding(UTF-8)", $lists->{$key}->{file});
    my @data = undef;
    while(<$fh>) {
      chomp;
      tr/"//d;
      tr/'//d;
      push @data, $_;
      last if $. == 5000; # only load the first 5000 entries
    }
    close($fh);
    shift @data;
    $anon_data{$lists->{$key}->{type}} = \@data;
    $l->debug("Loaded file '".$lists->{$key}->{file}."' with ".scalar(@data)." entries") if $l->is_debug();
  }
}

=head2 getLists

Gets the fake name lists and their respective types from the configured directory 'fakeNameListsDir' or from the given parameter

@PARAM1 OPTIONAL directory to look for fake name list, defaults to the configured value
@RETURNS HASHRef of HASHes, the fake name lists, eg.
  {
    emails => {
      file => emails.csv,
      type => emails,
    },
    ...
  }

=cut

memoize('getLists');
sub getLists {
  $l->debug("Getting available fake name lists");
  my ($fakeNameListsDir) = @_;
  my $c = SQLAnon::Config::getConfig();
  $fakeNameListsDir = $c->fakeNameListsDir unless ($fakeNameListsDir);

  my @filenames = glob($c->fakeNameListsDir.'/*.csv');
  my %lists;
  for (my $i=0 ; $i<scalar(@filenames) ; $i++) {
    my $file = $filenames[$i];
    $l->trace("Analyzing $file");
    my $type = File::Basename::basename($file, '.csv');
    my $list = {
      file => $file,
      type => $type,
    };
    $lists{$type} = $list;
    $l->trace("Analyzed $file as ".$l->flatten($list)) if $l->is_trace();
  }
  return \%lists;
}

=head2 get_value

Get a value from the array.  Array is looped so we don't run out of values

=cut

sub get_value {
  my ($type, $oldVal) = @_;
  my $value;
  if($type eq 'random') {
    $value = random_string();
  }
  elsif($type eq 'preserve') {
    $value = $oldVal;
  }
  else {
    $value = shift @{$anon_data{$type}};
    push @{$anon_data{$type}}, $value;
  }

  return $value;
}

sub random_string {
  my @chars = ("A".."Z", "a".."z");
  my $string;
  while(1) {
    $string .= $chars[ rand @chars ] for 1..8;
     last if ! $seen{$string};
  }
  return $string;
}

1;