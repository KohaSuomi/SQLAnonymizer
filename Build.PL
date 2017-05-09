## This file is part of mysql_anon
## https://github.com/PhlJns99/mysql_anon

use Modern::Perl;
use utf8;
binmode STDOUT, ":utf8";
binmode STDIN, ":utf8";


use Module::Build;

my $class = Module::Build->subclass(
  class => "Module::Build::Custom",
  code => <<'SUBCLASS' );

sub ACTION_install {
  my $self = shift;
  $self->SUPER::ACTION_install;
}

sub ACTION_test {
  my $self = shift;

  $self->do_system( '/usr/bin/prove -Ilib t' );
}

SUBCLASS

$class->new(
  module_name => 'MariaDB/MySQL Anonymizer',
  dist_author => 'PhlJns99',
  dist_abstract => 'Anonymizes DB backups',

  build_requires => {
    'Modern::Perl',
  },
  requires => {
    'Test::MockModule'                  => '> 0.01',
    'Text::CSV'                         => '> 0.01',
    'Memoize'                           => '> 0.01',
    'Log::Log4perl'                     => '> 0.01',
    'Params::Validate'                  => '> 0.01',
  },
)->create_build_script;

