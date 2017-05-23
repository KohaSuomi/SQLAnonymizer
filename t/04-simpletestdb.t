#!/usr/bin/perl

$ENV{SQLAnonMODE} = 'testing';

use Modern::Perl;
use utf8;
binmode(STDOUT, ":utf8");
binmode(STDERR, ":utf8");
binmode(STDIN, ":utf8");

use Test::More;



use SQLAnon;



#Don't try this at home!
#Create a binary representation of the same DB dump export value    04-testdb.sql => 'binaryblob'->[0]->{biblob}
#The binary has some strange chars and will break GUI editors so we have to deal with it in via hex-codes
my $binaryBlob = pack("H*","783839504e475c6e1a5c5c6e5c305c305c305c6e494844525c305c305c307838435c305c305c3078433908025c305c305c307e374d7842365c305c30205c304944415478783943347842427844397843452d59783932784144357843436c7843457845397845457841427846447839427844444478393319197844395465783943784141527839447842417845307838304008784238467838320b242e78384578383410475c5c784632183c160f7838305c305154517838442a2b78413332784133784439117842317839427842465d6b7937784137355c5c7845437843321f607843417845355366367c783843784346e89bbf7846445f7843426607425d1f78424278394319784536784145446631317a784337797d7846416e7d1e784231784439ddbc7c41784632337838340241784334017841352840101f485c5c6e784138784633087845364d405c094cc4815c304048010302784646784646435c30780b127845321e7841317841317841377842300b784543021250767d3278394224327841352d7841351d783838784531061078393843670f2666784633105a3c2ac3916e40784143deaa7841337845310678393478434378463869593e7839437845451e4f7841377556441c784146784145784245787846357846397839307a5073783834301278384205547839355c30115c5c6e783838783930372b783830137844");




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
    my ($stash, $tableName, $insertRowIndex, $columnName, $val, $unpack) = @_;
    if ($unpack) {
      is(unpack("H*", $stash->{$tableName}[$insertRowIndex]{$columnName}),
         $val,
         "$tableName $insertRowIndex $columnName");
    }
    else {
      is($stash->{$tableName}[$insertRowIndex]{$columnName}, $val,
         "$tableName $insertRowIndex $columnName");
    }
  };
  eval {
    ok($stash = SQLAnon::getAnonValStash(), "Given the stash of all anonymized values");

    &$testStash($stash, 'borrowers',     0,  'borrowernumber',   1);
    &$testStash($stash, 'borrowers',     0,  'email',            'nobody@example.com');

    &$testStash($stash, 'message_queue', 1,  'content',          'Ave Imperator, morituri te salutant');
    &$testStash($stash, 'message_queue', 1,  'to_address',       'nobody@example.com');

    &$testStash($stash, 'binaryblob',    0,  'description',      'Binary data mess');
    #&$testStash($stash, 'binaryblob',    0,  'biblob',           unpack("H*", $binaryBlob));
    &$testStash($stash, 'binaryblob',    0,  'biblob',           unpack("H*", $binaryBlob), 'unpack');
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