use Modern::Perl;
use utf8;
binmode STDOUT, ":utf8";
binmode STDERR, ":utf8";
use autodie;

package SQLAnon::Filters;

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

=head1 SQLAnon::Filters

=head2 SYNOPSIS

These filters are called to anonymize individual column values

=cut


#Preserve year
sub dateOfBirthAnonDayMonth {
  my ($class, $oldVal) = @_;
  $oldVal =~ s/-\d\d-\d\d/-01-01/;
  return $oldVal;
}

1;