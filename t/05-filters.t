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
use SQLAnon::Lists;


ok(SQLAnon::Lists::loadFakeNameLists(), 'Given fake name lists globally');


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



subtest "SQLAnon::Filters::addressWithSuffix", sub {
  my ($oldVal, $val);
  eval {
    $oldVal = 'Haimakatu 55';
    ok($val = SQLAnon::Filters->addressWithSuffix('borrowers', 'address', [$oldVal], 0),
       'Given filter params, we receive a filtered address');
    isnt($val, $oldVal,
       'address filtered');
  };
  ok(0, $@) if $@;
};



subtest "SQLAnon::Filters->killIfTimestampOlderThanYear", sub {
  my ($oldVal, $val);
  my $kill = '!KILL!';
  eval {
    $SQLAnon::Filters::year = 2017;
    $SQLAnon::Filters::mon = 4; #Starts from 0

    $oldVal = '2016-05-05T23:44:55';
    is(SQLAnon::Filters->killIfTimestampOlderThanYear('borrowers', 'address', [$oldVal], 0), $oldVal,
       'timestamp not older than year');

    $oldVal = '2015-12-05';
    is(SQLAnon::Filters->killIfTimestampOlderThanYear('borrowers', 'address', [$oldVal], 0), $kill,
       'timestamp kills');

    $oldVal = '2017-08-05';
    is(SQLAnon::Filters->killIfTimestampOlderThanYear('borrowers', 'address', [$oldVal], 0), $oldVal,
       'timestamp not older than year');
  };
  ok(0, $@) if $@;
};



done_testing;