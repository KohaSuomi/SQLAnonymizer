#!/usr/bin/perl

use Modern::Perl;
use utf8;
binmode(STDOUT, ":utf8");
binmode(STDERR, ":utf8");
binmode(STDIN, ":utf8");

use Test::More;

use Cwd;

$ENV{SQLAnonMODE} = 'testing';
$ENV{SQLAnonCONF} = getcwd().'/t/config/04-simpletestdb.conf';


use SQLAnon;



#Don't try this at home!
#Create a binary representation of the same DB dump export value    04-testdb.sql => 'binaryblob'->[0]->{biblob}
#The binary has some strange chars and will break GUI editors so we have to deal with it in via hex-codes
#This actually is a white 1x1px .png image
my $binaryBlob = pack("H*","89504e475c725c6e5c5a5c6e5c305c305c305c72494844525c305c305c30015c305c305c300101035c305c305c3025db56ca5c305c305c3003504c5445fcfefc2590c56a5c305c305c3009704859735c305c300b135c305c300b13015c309a9c185c305c305c305c6e49444154089963605c305c305c30025c3001f47164a65c305c305c305c3049454e44ae426082");



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
    my ($stash, $tableName, $insertRowIndex, $columnName, $val, $unpack, $missing) = @_;
    my $expectedVal = ($unpack) ? unpack("H*", $stash->{$tableName}[$insertRowIndex]{$columnName}) : $stash->{$tableName}[$insertRowIndex]{$columnName};
    is($expectedVal, $val,
       "$tableName $insertRowIndex $columnName") unless $missing;
    isnt($expectedVal, $val,
       "$tableName $insertRowIndex $columnName") if $missing;
  };
  eval {
    ok($stash = SQLAnon::getAnonValStash(), "Given the stash of all anonymized values");

    &$testStash($stash, 'borrowers',     0,  'borrowernumber',   1);
    &$testStash($stash, 'borrowers',     0,  'email',            'nobody@example.com');
    &$testStash($stash, 'borrowers',     0,  'othernames',       '☻☻☻☻');
    &$testStash($stash, 'borrowers',     1,  'borrowernumber',   2);
    &$testStash($stash, 'borrowers',     1,  'email',            '!KILL!');
    &$testStash($stash, 'borrowers',     2,  'borrowernumber',   3);

    &$testStash($stash, 'message_queue', 0,  'to_address',       'nobody@example.com');
    &$testStash($stash, 'message_queue', 1,  'content',          'Ave Imperator, morituri te salutant');
    &$testStash($stash, 'message_queue', 1,  'to_address',       'nobody@example.com');
    &$testStash($stash, 'message_queue', 2,  'to_address',       'nobody@example.com');

    &$testStash($stash, 'binaryblob',    0,  'description',      'Binary\'data\'mess');

    &$testStash($stash, 'killable',      0,  'content',          'kill',      undef,         'expected missing');
    TODO: {
      local $TODO = "Text::CSV removes double escapes from binary output. This happens only when we anonymize binary data, which makes no sense.";
      &$testStash($stash, 'binaryblob',    0,  'biblob',           unpack("H*", $binaryBlob), 'unpack');
    };
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