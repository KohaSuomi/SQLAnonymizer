#!/usr/bin/perl

$ENV{SQLAnonMODE} = 'testing';

use Modern::Perl;
use utf8;
binmode(STDOUT, ":utf8");
binmode(STDERR, ":utf8");
binmode(STDIN, ":utf8");

use Test::More;



use SQLAnon;

#The way the state machine has been constructed requires us to do the full run of everything first. The mapping tables are generated while the insert statements are anonymized.
#After the whole run is complete, we can inspect if the mapping tables worked ok.
subtest "Initialize and execute", sub {
  eval {
    ok(SQLAnon::init(),
       "SQLAnon::init success");
    is(SQLAnon::Config::getConfig()->outputFile, '/tmp/sqlanon_test_output.sql',
       'SQL is outputed to "/tmp/sqlanon_test_output.sql"');
    ok(SQLAnon::anonymize(),
       "SQLAnon::anonymize success");
  };
  ok(0, $@) if $@;
};

subtest "Verify anonymized values", sub {
  my ($stash);
  my $testStash = sub {
    my ($stash, $tableName, $insertRowIndex, $columnName, $val) = @_;
    is($stash->{$tableName}[$insertRowIndex]{$columnName}, $val,
       "$tableName $insertRowIndex $columnName")
  };
  eval {
    ok($stash = SQLAnon::getAnonValStash(), "Given the stash of all anonymized values");

    &$testStash($stash, 'borrowers',     0,  'borrowernumber',   1);
    &$testStash($stash, 'borrowers',     0,  'email',            'nobody@example.com');

    &$testStash($stash, 'message_queue', 1,  'content',          'Ave Imperator, morituri te salutant');
    &$testStash($stash, 'message_queue', 1,  'to_address',       'nobody@example.com');
  };
  ok(0, $@) if $@;
};

subtest "SQLAnon::_get_anon_col_index", sub {
  my (@colIndexes);
  eval {
    ok(@colIndexes = SQLAnon::_get_anon_col_index('borrowers'), "Given anonymizable column indexes");

    is(scalar(@colIndexes), 12, "Received all anonymizable indexes");
    is($colIndexes[0],   0, "Idx 0 is ok");
    is($colIndexes[1],   2, "Idx 1 is ok");
    is($colIndexes[11], 13, "Idx 11 is ok");
  };
  ok(0, $@) if $@;
};



subtest "SQLAnon::_trimValToFitColumn", sub {
  my ($val);
  eval {
    ok($val = SQLAnon::_trimValToFitColumn('borrowers', 'password', '42b29d0771f3b7ef', '$6$bmpusw./X$TkzFd8RSlVsPVNtGWmIgDDE9eV.FzK5WM/86EEZ3KtJOlAfwO6YtQLkm/jLQJUCpgdJKU5Ou4kAKiyEitrq/N.'),
       "Given long passwords, we receive the trimmed value");
    is($val, '$6$bmpusw./X$TkzFd8RSlVsPVNtGWmIgDDE9eV.FzK5WM/86EEZ3KtJOlAfwO6YtQLkm/jLQJUCpgdJKU5Ou4kAKiyEitrq/N.',
       "Received password is untrimmed");
  };
  ok(0, $@) if $@;
};







done_testing;