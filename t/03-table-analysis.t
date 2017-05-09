#!/usr/bin/perl

$ENV{SQLAnonMODE} = 'testing';

use Modern::Perl;
use utf8;
binmode(STDOUT, ":utf8");
binmode(STDERR, ":utf8");
binmode(STDIN, ":utf8");

use Test::More;



use SQLAnon;


subtest "SQLAnon::_getColSize", sub {
  my $lists;
  eval {
    is(SQLAnon::_getColSize('text', undef), 1024,
       "Given type 'text', correct size received");

    is(SQLAnon::_getColSize('mediumtext', undef), 1024,
       "Given type 'mediumtext', correct size received");

    is(SQLAnon::_getColSize('date', undef), 10,
       "Given type 'date', correct size received");

    is(SQLAnon::_getColSize('varchar', 44), 44,
       "Given type 'varchar' with size, correct size received");
  };
  ok(0, $@) if $@;
};








done_testing;