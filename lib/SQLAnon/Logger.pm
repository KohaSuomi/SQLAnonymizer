use Modern::Perl;
use utf8;
binmode STDOUT, ":utf8";
binmode STDERR, ":utf8";
use autodie;

package SQLAnon::Logger;

use Carp qw(longmess);
$Carp::Verbose = 'true'; #die with stack trace
use Try::Tiny;
use Scalar::Util qw(blessed);
use Params::Validate;

# Copyright (C) 2017 Koha-Suomi
#
# This file is part of SQL Anonymizer.

use Data::Dumper;
use Cwd;

use Log::Log4perl;
our @ISA = qw(Log::Log4perl);
Log::Log4perl->wrapper_register(__PACKAGE__);

sub AUTOLOAD {
  my $l = shift;
  my $method = our $AUTOLOAD;
  $method =~ s/.*://;
  return $l->$method(@_) if $method eq 'DESTROY';
  unless (blessed($l)) {
    longmess __PACKAGE__." invoked with an unblessed reference??";
  }
  unless ($l->{_log}) {
    _init();
    $l->{_log} = Log::Log4perl->get_logger();
  }
  return $l->{_log}->$method(@_);
}

sub DESTROY {}

=head2 flatten

    my $string = $logger->flatten(@_);

Given a bunch of $@%, the subroutine flattens those objects to a single human-readable string.

@PARAMS Anything, concatenates parameters to one flat string

=cut

sub flatten {
  my $self = shift;
  die __PACKAGE__."->flatten() invoked improperly. Invoke it with \$logger->flatten(\@params)" unless ((blessed($self) && $self->isa(__PACKAGE__)) || ($self eq __PACKAGE__));
  $Data::Dumper::Indent = 0;
  $Data::Dumper::Terse = 1;
  $Data::Dumper::Quotekeys = 0;
  $Data::Dumper::Maxdepth = 2;
  $Data::Dumper::Sortkeys = 1;
  return Data::Dumper::Dumper(\@_);
}

sub _init {
  if(Log::Log4perl->initialized()) {
    # Yes, Log::Log4perl has already been initialized
  } else {
    my $confFile;
    my @confFileTries = (getcwd().'/config/log4perl.conf', getcwd().'/../config/log4perl.conf', '/etc/SQLAnon/log4perl.conf');
    foreach my $candidate (@confFileTries) {
      if (-e $candidate) {
        $confFile = $candidate;
        last;
      }
    }
    unless ($confFile) {
      die "Cannot find Log4perl configuration file from these locations: @confFileTries";
    }
    Log::Log4perl->init($confFile);
    my $log = Log::Log4perl->get_logger();
    $log->info("Initialized Log4perl from $confFile");
  }
}

1;
