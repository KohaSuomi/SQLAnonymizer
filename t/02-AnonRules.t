#!/usr/bin/perl

$ENV{SQLAnonMODE} = 'testing';

use Modern::Perl;
use utf8;
binmode(STDOUT, ":utf8");
binmode(STDERR, ":utf8");
binmode(STDIN, ":utf8");

use Test::More;



use SQLAnon::AnonRules;


subtest "SQLAnon::AnonRules::loadAnonymizationRules", sub {
  my ($rule, $coderefContent);
  $Data::Dumper::Deparse = 1;
  eval {
    ok(SQLAnon::AnonRules::loadAnonymizationRules(), 'Given anonymization rules');

    ok($rule = SQLAnon::AnonRules::getRule('borrowers', 'title'), 'Got rule for borrower-title');
    is($rule->{fakeNameList}, 'adjective',                        'Rule uses a fake name list');

    ok($rule = SQLAnon::AnonRules::getRule('borrowers', 'dateofbirth'), 'Got rule for borrower-dateofbirth');
    is($rule->{filter}, 'dateOfBirthAnonDayMonth',                      'Rule uses a filter');

    ok($rule = SQLAnon::AnonRules::getRule('message_queue', 'content'), 'Got rule for message_queue-content');
    like($rule->{dispatch}, qr/Ave Imperator, morituri te salutant/,    'Rule uses injectable perl code');

  };
  ok(0, $@) if $@;
};








done_testing;