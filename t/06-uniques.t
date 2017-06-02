#!/usr/bin/perl

use Modern::Perl;
use utf8;
binmode(STDOUT, ":utf8");
binmode(STDERR, ":utf8");
binmode(STDIN, ":utf8");

use Try::Tiny;
use Test::More;

use Cwd;

$ENV{SQLAnonMODE} = 'testing';
$ENV{SQLAnonCONF} = getcwd().'/t/config/06-uniques.conf';


use SQLAnon;

#The way the state machine has been constructed requires us to do the full run of everything first. The mapping tables are generated while the insert statements are anonymized.
#After the whole run is complete, we can inspect if the mapping tables worked ok.
subtest "Initialize and execute. Die because a UNIQUE value couldn't be generated", sub {
  eval {
    ok(SQLAnon::init(),
       "SQLAnon::init success");
    is(SQLAnon::Config::getConfig()->outputFile, '/tmp/sqlanon_test_output.sql',
       'SQL is outputed to "/tmp/sqlanon_test_output.sql"');
    try {
      ok(SQLAnon::anonymize(),
         "SQLAnon::anonymize success");
      ok(0, "SQLAnon::anonymize() must die horribly due to a duplicate exception");
    } catch {
      like($_, qr/UNIQUE.+endless loop!/, "SQLAnon::anonymize() died of probable causes.")
    };
  };
  ok(0, $@) if $@;
};

subtest "Verify anonymized values", sub {
  my ($stash);
  eval {
    ok($stash = SQLAnon::getAnonValStash(), "Given the stash of all anonymized values");

    is ($stash->{'borrowers'}[0]{'cardnumber'}, '☻☻☻☻',
        "0 cardnumber ok");
    is ($stash->{'borrowers'}[0]{'othernames'}, 'a-duplicate-value',
        "0 othernames ok");
    is ($stash->{'borrowers'}[1]{'cardnumber'}, 'Nightrider',
        "1 cardnumber ok");
    is ($stash->{'borrowers'}[1]{'othernames'}, undef,
        "1 But crashed when getting non-duplicate value for othernames");
  };
  ok(0, $@) if $@;
};



done_testing;