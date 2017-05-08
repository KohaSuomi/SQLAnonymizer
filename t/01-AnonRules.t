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

    ok($rule = SQLAnon::AnonRules::getRule('borrowers', 'email'), 'Got rule for borrower-email');
    is(ref($rule->{dispatch}), 'CODE', 'Rule has a dispatch subroutine');
    ok($coderefContent = Data::Dumper::Dumper($rule->{dispatch}), 'Code reference deparsed');
    like($coderefContent, qr/nobody\@example\.com/, 'Code injected reference as expected');

    ok($rule = SQLAnon::AnonRules::getRule('message_queue', 'content'), 'Got rule for message_queue-content');
    is(ref($rule->{dispatch}), 'CODE', 'Rule has a dispatch subroutine');
    ok($coderefContent = Data::Dumper::Dumper($rule->{dispatch}), 'Code reference deparsed');
    like($coderefContent, qr/Ave Imperator, morituri te salutant/, 'Code injected reference as expected');
  };
  ok(0, $@) if $@;
};








done_testing;