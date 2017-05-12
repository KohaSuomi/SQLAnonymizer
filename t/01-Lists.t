#!/usr/bin/perl

$ENV{SQLAnonMODE} = 'testing';

use Modern::Perl;
use utf8;
binmode(STDOUT, ":utf8");
binmode(STDERR, ":utf8");
binmode(STDIN, ":utf8");

use Try::Tiny;
use Scalar::Util qw(blessed);

use Test::More;



use SQLAnon::Lists;


ok(SQLAnon::Lists::loadFakeNameLists('t/fakeNameLists'), 'Given test fake name lists globally');


subtest "SQLAnon::Lists::getFakeNameLists", sub {
  my $lists;
  eval {
    ok($lists = SQLAnon::Lists::getFakeNameLists(),     'Given fake name lists');
    ok($lists->{email},                                 'email list exists');
    like($lists->{email}->{file}, qr/\/email.csv$/,     'email list file ok');
    is($lists->{email}->{type}, 'email',                'email list type ok');
    ok($lists->{address},                               'address list exists');
    like($lists->{address}->{file}, qr/\/address.csv$/, 'address list file ok');
    is($lists->{address}->{type}, 'address',            'address list type ok');
  };
  ok(0, $@) if $@;
};


subtest "SQLAnon::Lists::get_value nonexistant fake name list", sub {
  my ($list, $val);
  eval {
    try {
      $val = SQLAnon::Lists::get_value('this-doesnt-exist', 'ov');
      is($val, 'THIS SHOULD CRASH INSTEAD', "get_value() is expected to crash, not return a value!!");
    } catch {
      like($_, qr/Unknown fake name list 'this-doesnt-exist', old value 'ov'!/, 'Got the proper exception when accessing non-existent fake name list');
    };
  };
  ok(0, $@) if $@;
};


subtest "SQLAnon::Lists::get_value exhaust list and rewind iterator", sub {
  my ($list, $val);
  eval {
    is(SQLAnon::Lists::get_value('01-test'), 'Led to the river',
       "1. value pop'd and as expected");
    is(SQLAnon::Lists::get_value('01-test'), 'Midsummer I wave',
       "2. value pop'd and as expected");

    #Keep popping until the array is empty
    SQLAnon::Lists::get_value('01-test') for (1..67);

    is(SQLAnon::Lists::get_value('01-test'), 'My nymphetamine girl',
       "last value pop'd and as expected");
    is(SQLAnon::Lists::get_value('01-test'), 'Led to the river',
       "1. value pop'd again and as expected");
  };
  ok(0, $@) if $@;
};





done_testing;