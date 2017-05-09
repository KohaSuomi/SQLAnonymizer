use Modern::Perl;
use utf8;
binmode STDOUT, ":utf8";
binmode STDERR, ":utf8";
use autodie;

package SQLAnon::Config;

use Carp qw(longmess);
$Carp::Verbose = 'true'; #die with stack trace
use Try::Tiny;
use Scalar::Util qw(blessed);
use Params::Validate;

# Copyright (C) 2017 Koha-Suomi
#
# This file is part of SQL Anonymizer.

use Cwd;
use File::Basename;

=head1 SQLAnon::Config

=head2 SYNOPSIS

Module for loading all configurations and name lists

=cut

=head2 getConfig

Looks for the config file from a few locations and reads it as perl code.
@RETURNS HASHRef of the config.

=cut

my $config;
my $configValidations = {
  fakeNameListsDir =>       { callbacks => { 'file exists' => sub {return (-e $_[0]) ? 1 : 0;} }, },
  anonymizationRulesFile => { callbacks => { 'file exists' => sub {return (-e $_[0]) ? 1 : 0;} }, },
  dbBackupFile =>           { callbacks => { 'file exists or is -' => sub {return ($_[0] eq '-' || -e $_[0]) ? 1 : 0;} }, },
  outputFile =>             { callbacks => { 'dir is writable or is -' => sub {return ($_[0] eq '-' || -w File::Basename::dirname($_[0])) ? 1 : 0;} }, },
};
sub getConfig {
  return $config if $config;

  my $confFile;
  my @confFileTries = (getcwd().'/config/SQLAnon.conf', getcwd().'/../config/SQLAnon.conf', '/etc/SQLAnon/SQLAnon.conf');

  if ($ENV{SQLAnonMODE} && $ENV{SQLAnonMODE} eq 'testing') {
    @confFileTries = (getcwd().'/t/config/SQLAnon.conf');
  }
  foreach my $candidate (@confFileTries) {
    if (-e $candidate) {
      $confFile = $candidate;
      last;
    }
  }
  unless ($confFile) {
    die "Cannot find SQL Anonymizer configuration file from these locations: @confFileTries";
  }
  unless ($config = do $confFile) {
    die "couldn't parse $confFile: $@" if $@;
    die "couldn't do $confFile: $!"    unless defined $config;
    die "couldn't run $confFile"       unless $config;
  }
  _validateConfig($config);
  bless($config, __PACKAGE__);
  return $config;
}
sub _validateConfig {
  Params::Validate::validate(@_, $configValidations);
}



##############################################################################################
############  Configuration file accessors  ###################################################
sub fakeNameListsDir {
  return $_[0]->{fakeNameListsDir};
}
sub anonymizationRulesFile {
  return $_[0]->{anonymizationRulesFile};
}
sub dbBackupFile {
  return $_[0]->{dbBackupFile};
}
sub outputFile {
  return $_[0]->{outputFile};
}

1;