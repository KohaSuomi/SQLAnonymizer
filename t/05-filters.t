#!/usr/bin/perl

$ENV{SQLAnonMODE} = 'testing';

use Modern::Perl;
use utf8;
binmode(STDOUT, ":utf8");
binmode(STDERR, ":utf8");
binmode(STDIN, ":utf8");

use Test::More;
use Test::MockModule;



use SQLAnon::Filters;


subtest "SQLAnon::Filters::dateOfBirthAnonDayMonth", sub {
  my $dob;
  eval {
    ok($dob = SQLAnon::Filters->dateOfBirthAnonDayMonth('borrowers', 'dateofbirth', ['1968-03-22'], 0),
       'Given filter params, we receive a filtered dob');
    is($dob, '1968-01-01',
       'dob got day and month anonymized');
  };
  ok(0, $@) if $@;
};



subtest "SQLAnon::Filters::kohaSystempreferences", sub {
  my $val;
  eval {
    my $moduleSQLAnon = Test::MockModule->new('SQLAnon');
    $moduleSQLAnon->mock('getColumnIndexByName', sub {
      return 0;
    });


    ok($val = SQLAnon::Filters->kohaSystempreferences('systempreference', 'value', ['VaaraAcqVendorConfigurations','anonymizable value'], 1),
       'Given filter params, we receive a filtered syspref');
    is($val, "---\n\n",
       'syspref filtered');

    ok($val = SQLAnon::Filters->kohaSystempreferences('systempreference', 'value', ['AutoSelfCheckPass','anonymizable value'], 1),
       'Given filter params, we receive a filtered syspref');
    is($val, "1234",
       'syspref filtered');
  };
  ok(0, $@) if $@;
};







done_testing;