use Modern::Perl;
#use utf8;
#binmode STDOUT, ":utf8";
#binmode STDERR, ":utf8";
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
my %anon_data_iterator;

my $isCommentRegexp = qr/^#/;
sub loadFakeNameLists {
  my ($fakeNameListsDir) = @_;
  $l->debug("Loading anonymized lists");

  my $c = SQLAnon::Config::getConfig();
  my $fakeNameListMaxSize = $c->fakeNameListMaxSize();

  # load in the anon data
  my $lists = getFakeNameLists($fakeNameListsDir);

  my $slurpRow = sub {
    my ($row, $data) = @_;
    return undef if $row =~ $isCommentRegexp;
    chomp $row;
    tr/"//d;
    tr/'//d;
    push(@$data, $row) if (length($row) > 0);
    return undef;
  };

  foreach my $key (sort keys %$lists) {
    $l->trace("Loading $key");
    #open(my $fh, "<:encoding(UTF-8)", $lists->{$key}->{file}) or $l->logdie("Can't open fake name list '".$lists->{$key}->{file}."': $!");
    open(my $fh, "<", $lists->{$key}->{file}) or $l->logdie("Can't open fake name list '".$lists->{$key}->{file}."': $!");
    my @data;
    while(<$fh>) {
      if ($fakeNameListMaxSize == -1) {
        #Load all the rows
        &$slurpRow($_, \@data);
      }
      elsif ($. <= $fakeNameListMaxSize) {
        #Keep loading since we haven't reached the maximum yet
        &$slurpRow($_, \@data);
      }
      else {
        last;
      }
    }
    close($fh);
    $anon_data{$lists->{$key}->{type}} = \@data;
    $anon_data_iterator{$lists->{$key}->{type}} = 0;
    $l->debug("Loaded file '".$lists->{$key}->{file}."' with ".scalar(@data)." entries") if $l->is_debug();
  }
  return 1;
}

=head2 getFakeNameLists

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

memoize('getFakeNameLists');
sub getFakeNameLists {
  my ($fakeNameListsDir) = @_;
  $l->debug("Getting available fake name lists");
  my $c = SQLAnon::Config::getConfig();
  $fakeNameListsDir = $c->fakeNameListsDir unless ($fakeNameListsDir);

  my @filenames = glob($fakeNameListsDir.'/*.csv');
  my %lists;
  for (my $i=0 ; $i<scalar(@filenames) ; $i++) {
    my $file = $filenames[$i];
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
If fake name lists are disbled with the fakeNameListMaxSize == 0, returns ''

=cut

sub get_value {
  my ($type, $oldVal) = @_;
  my $value;
  if($type eq 'preserve') {
    $value = $oldVal;
  }
  elsif($type eq '!KILL!') {
    $value = '!KILL!';
  }
  elsif($anon_data{$type}) {
    my $iterator = $anon_data_iterator{$type}++;
    $value = (defined($anon_data{$type}[$iterator])) ? $anon_data{$type}[$iterator] : '';
    $anon_data_iterator{$type} = 0 unless ($anon_data_iterator{$type} < scalar(@{$anon_data{$type}})); #If iterator has passed the array end, rewind it
  }
  else {
    $l->logdie("Unknown fake name list '$type', old value '$oldVal'!");
  }
  return $value;
}

1;