#!/usr/bin/perl

$ENV{SQLAnonMODE} = 'testing';

use Modern::Perl;
use utf8;
binmode(STDOUT, ":utf8");
binmode(STDERR, ":utf8");
binmode(STDIN, ":utf8");

use Test::More;



use SQLAnon::Lists;


subtest "SQLAnon::Lists::getLists", sub {
  my $lists;
  eval {
    ok($lists = SQLAnon::Lists::getLists(),           'Given fake name lists');
    ok($lists->{email},                               'email list exists');
    like($lists->{email}->{file}, qr/\/email.csv$/,   'email list file ok');
    ok($lists->{address},                             'address list exists');
    like($lists->{address}->{file}, qr/\/address.csv$/, 'address list file ok');
  };
  ok(0, $@) if $@;
};








done_testing;