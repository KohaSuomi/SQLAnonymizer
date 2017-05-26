#!/usr/bin/perl

$ENV{SQLAnonMODE} = 'testing';

use Modern::Perl;
use utf8;
binmode(STDOUT, ":utf8");
binmode(STDERR, ":utf8");
binmode(STDIN, ":utf8");

use Test::More;
use Test::MockModule;

use Time::HiRes;

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



subtest "SQLAnon::Filters->randomString", sub {
  my ($oldVal, $val, $val2);

  eval {
    $oldVal = '167A001234';
    ok($val = SQLAnon::Filters->randomString('borrowers', 'cardnumber', [$oldVal], 0),
       'Given a cardnumber, we receive a anonymized string');
    is(length($val), $SQLAnon::Filters::stringLength,
       'With correct length');

    ok($val2 = SQLAnon::Filters->randomString('borrowers', 'cardnumber', [$oldVal], 0),
       'Given the same cardnumber again, we receive a anonymized string');
    is($val, $val2,
       'And the anonymized strings are the same, because the source strings are the same');

    $oldVal = '167A004321';
    ok($val = SQLAnon::Filters->randomString('borrowers', 'cardnumber', [$oldVal], 0),
       'Given a new cardnumber, we receive a anonymized string');
    isnt($val, $val2,
       'And the anonymized strings are different, because the source strings are different');


    ##Performance test
    my $start = Time::HiRes::time;
    for (0..10000) {
      SQLAnon::Filters->randomString('borrowers', 'cardnumber', [rand(9999)], 0);
    }
    my $dur = Time::HiRes::time - $start;
    my $threshold = 100;
    ok($dur < $threshold, "Runtime '$dur' less than '$threshold'. Performance kinda ok'ish");
  };
  ok(0, $@) if $@;
};



done_testing;