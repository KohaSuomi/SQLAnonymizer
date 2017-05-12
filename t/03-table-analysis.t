#!/usr/bin/perl

$ENV{SQLAnonMODE} = 'testing';

use Modern::Perl;
use utf8;
binmode(STDOUT, ":utf8");
binmode(STDERR, ":utf8");
binmode(STDIN, ":utf8");

use Test::More;
use Test::MockModule;



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




subtest "SQLAnon::decompose/recompose insert statement", sub {
  my ($tableName, $insertStatement, $insertPrefix, $valueStrings, $valueStrings2, $valueColumns, $metaColumns, $valueString);
  my @originalValueStrings;
  my $originalInsertStatement = "INSERT INTO `borrowers` VALUES ";
  $originalValueStrings[0] =    "1,'1','ÄÄDMÖN','Köhä','',NULL,'BREAK,CHAR,TEXT::CSV',NULL,'MPL','S',NULL,'2099-12-31',NULL";
  $originalValueStrings[1] =    "2,'term1','SIP-Server','Sippy2','',NULL,'5601 Library Rd.','(212) 555-1212',NULL,'CPL','ST','1985-10-24','2020-12-31','\$2a\$08\$Qz/FkOMmEne3.m0WoYHvZ.4eVNuNmX9ZGzRntt9aircQSWj0D5Oxm'";
  $originalValueStrings[2] =    "3,'23529000445172','Daniels','Tanya','',NULL,'2035 Library Rd.','(212) 555-1212','1966-10-14','MPL','PT','1990-08-22','2020-12-31','42b29d0771f3b7ef'";
  $originalValueStrings[3] =    "4,'23529000105040','Dillon','Eva','',NULL,'8916 Library Rd.','(212) 555-1212','1952-04-03','MPL','PT','1987-07-01','2020-12-31','42b29d0771f3b7ef'";
  $originalInsertStatement .= '('.join('),(', @originalValueStrings).");\n";
  ## We end up with this structure:
  ## INSERT INTO `borrowers` VALUES (1,'1','Admin','Koha','',NULL,'',NULL,'MPL','S',NULL,'2099-12-31',NULL),(2,'term1','SIP-Server','Sippy2','',NULL,'5601 Library Rd.','(212) 555-1212',NULL,'CPL','ST','1985-10-24','2020-12-31','\$2a\$08\$Qz/FkOMmEne3.m0WoYHvZ.4eVNuNmX9ZGzRntt9aircQSWj0D5Oxm'),(3,'23529000445172','Daniels','Tanya','',NULL,'2035 Library Rd.','(212) 555-1212','1966-10-14','MPL','PT','1990-08-22','2020-12-31','42b29d0771f3b7ef'),(4,'23529000105040','Dillon','Eva','',NULL,'8916 Library Rd.','(212) 555-1212','1952-04-03','MPL','PT','1987-07-01','2020-12-31','42b29d0771f3b7ef');

  eval {
    my $moduleSQLAnon = Test::MockModule->new('SQLAnon');
    $moduleSQLAnon->mock('getColumnNameByIndex', sub {
      return 'mocked'; #Logger needs this, otherwise undef errors
    });

    ok(($tableName, $insertPrefix, $valueStrings) = SQLAnon::decomposeInsertStatement($originalInsertStatement),
       "Given a INSERT statement, we receive table name, the statement prefix and individual VALUE groups");

    is($tableName, 'borrowers',
       "Then table name is correct");

    is($insertPrefix, 'INSERT INTO `borrowers` VALUES (',
       "Then the INSERT prefix without VALUE-groups is as expected");

    is(ref($valueStrings), 'ARRAY',
       "Then the value groups are in an array");

    is(scalar(@$valueStrings), 4,
       "Then there are the correct amount of value groups");

    for (my $i=0 ; $i<scalar(@originalValueStrings) ; $i++) {
      is($valueStrings->[$i], $originalValueStrings[$i],
         "Then the $i. value group is as expected");
    }


    $valueColumns = [];
    $metaColumns  = [];
    ok(($valueColumns->[0], $metaColumns->[0]) = SQLAnon::decomposeValueGroup($valueStrings->[0]), "Given the decomposed 1. value group");
    is_deeply($valueColumns->[0],    [ 1,'1','ÄÄDMÖN','Köhä','','NULL','BREAK,CHAR,TEXT::CSV','NULL','MPL','S','NULL','2099-12-31','NULL' ],
      "Then 1. columns match");
    ok(($valueColumns->[1], $metaColumns->[1]) = SQLAnon::decomposeValueGroup($valueStrings->[1]), "Given the decomposed 2. value group");
    is_deeply($valueColumns->[1],    [ 2,'term1','SIP-Server','Sippy2','','NULL','5601 Library Rd.','(212) 555-1212','NULL','CPL','ST','1985-10-24','2020-12-31','$2a$08$Qz/FkOMmEne3.m0WoYHvZ.4eVNuNmX9ZGzRntt9aircQSWj0D5Oxm' ],
      "Then 2. columns match");
    ok(($valueColumns->[2], $metaColumns->[2]) = SQLAnon::decomposeValueGroup($valueStrings->[2]), "Given the decomposed 3. value group");
    is_deeply($valueColumns->[2],    [ 3,'23529000445172','Daniels','Tanya','','NULL','2035 Library Rd.','(212) 555-1212','1966-10-14','MPL','PT','1990-08-22','2020-12-31','42b29d0771f3b7ef' ],
      "Then 3. columns match");
    ok(($valueColumns->[3], $metaColumns->[3]) = SQLAnon::decomposeValueGroup($valueStrings->[3]), "Given the decomposed 4. value group");
    is_deeply($valueColumns->[3],    [ 4,'23529000105040','Dillon','Eva','','NULL','8916 Library Rd.','(212) 555-1212','1952-04-03','MPL','PT','1987-07-01','2020-12-31','42b29d0771f3b7ef' ],
      "Then 4. columns match");


    $valueStrings2 = []; #Collect the recomposed value groups here
    for (my $i=0 ; $i<scalar(@originalValueStrings) ; $i++) {
      ok($valueStrings2->[$i] = SQLAnon::recomposeValueGroup($tableName, $valueColumns->[$i], $metaColumns->[$i]), "Given the $i. decomposed value group, we receive a recomposed VALUE string");
      is($valueStrings2->[$i], $originalValueStrings[$i],
         "Then the $i. value string is the same as before decomposing");
    }

    ok($insertStatement = SQLAnon::recomposeInsertStatement($insertPrefix, $valueStrings2),
       "Given the recomposed value strings and INSERT prefix, we get the complete new INSERT statement");
    is($insertStatement, $originalInsertStatement,
       "Then the new insert statement is the same as the original one");
  };
  ok(0, $@) if $@;
};




done_testing;