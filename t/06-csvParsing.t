#!/usr/bin/perl
use Modern::Perl;

=head
use SQLAnon;

##Same /), (/-pattern exists inside quoted column data, can csv-parser deal with this?
my $insertGroupSeparatorInsideQuotes = q{INSERT INTO `action_logs` VALUES (8536592,'2016-10-07 22:11:15',0,'CATALOGUING','MODIFY',2818677,'biblio BEFORE=>LDR 01307ngm a2200433   4500\n001     8C35F59C-D1F7-4822-9D4B-5613A909030F\n003     FI-Joro\n005     20160805011056.0\n007        b\n008     110208s2011    fi ||||e |||||||||z|eng|c\n024 3  _a5709165592324\n028 41 _bSoul Media\n       _a8859232\n035    _a8C35F59C-D1F7-4822-9D4B-5613A909030F\n041 0  _aeng\n       _jfin\n       _jswe\n       _jdan\n       _jnor\n049    _cK18\n084    _a84.2\n       _2ykl\n090    _a84.2\n130 4  _aThe dancing masters\n245 10 _aTanssikoulu\n       _h[Videotallenne].\n260    _a[S.I.] :\n       _bSoul Media,\n       _c[2011]\n300    _a1 DVD-videolevy, 1 BD-videolevy :\n       _b(60 min), (60 min.), mv.\n500    _aKielletty alle 18-v.\n500    _aÄäniraita: englanti ; tekstitys: suomi, ruotsi, tanska, norja.\n534    _pAlkuperäinen:\n       _cTwentieth Century Fox Film, 1943.\n590    _a-1DVD+1BD\n650  7 _akomediat\n       _2kaunokki\n650  7 _aelokuvat\n       _zYhdysvallat\n       _y1940-luku\n       _2kaunokki\n700 1  _aSt. Clair, Mal.\n700 1  _aDarling, W. Scott.\n700 1  _aLaurel, Stan.\n700 1  _aHardy, Oliver.\n700 1  _aMarshall, Trudy.\n700 1  _aBailey, Robert.\n700 1  _aBriggs, Matt.\n700 1  _aDumont, Margaret.\n700 1  _aLane, Allan.\n700 1  _aOhukainen ja Paksukainen.\n942 00 _03\n999    _c2818677\n       _d2818677',NULL),(8536593,'2016-10-07 22:11:15',0,'CATALOGUING','MODIFY',2820382,'biblio BEFORE=>LDR 01553nam a2200349   4500\n001     EBDD3E87-53BD-40F6-A550-CA70AB379E41\n003     FI-Joro\n005     20160902011122.0\n008     091208s2010    fi ||||j|66   ||||1|fin|c\n020    _a9789513228811 (sid.)\n035    _aEBDD3E87-53BD-40F6-A550-CA70AB379E41\n041 1  _afin\n       _hita\n080    _a741.5\n084    _a85.32\n       _2ykl\n090    _a85.32\n090    _a85.32\n090    _a85.32\n245 00 _aTaskarin juhlakirja :\n       _bAku Ankan taskukirja 40 vuotta 1971-2010 /\n       _c[toimitus: Anna Kastari ... et al. ; suomennokset: Kirsi Ahonen ... et al.].\n246 3  _aAku Ankan taskukirja 40 vuotta 1971-2010\n260    _aHelsinki :\n       _bSanoma Magazines Finland,\n       _c2010\n       _e(Porvoo :\n       _fWS Bookwell)\n300    _a336 s. :\n       _bkuv. ;\n       _c26 cm.\n500    _aIlmestyy maaliskuussa 2010.\n500    _aOsa sarjoista ilmestynyt aiemmin Aku Ankan taskukirja -sarjassa.\n500    _aWalt Disney -tuotantoa.\n700 1  _aKastari, Anna.\n700 1  _aAhonen, Kirsi.\n856 42 _uhttp://www.btj.com/btjcgi/arvo/get_add_info.cgi?type=PRES&key=6598675235718681\n       _qTEXT\n       _zKuvaus\n856 42 _uhttp://www.btj.com/btjcgi/arvo/get_add_info.cgi?type=IMAGE&key=6598675235718681\n       _qIMAGE\n       _zKansikuva\n971    _aBTJ\n       _bT100120\n       _dSanoma Magazines 1/10\n       _c20100124\n       _e26,85EUR\n       _f8%\n       _i22\n       _p2,47\n       _sC11-\n       _t020\n       _uhttp://www.btj.com/btjcgi/arvo/get_add_info.cgi?type=PRES&key=6598675235718681\n       _xKuvaus\n       _uhttp://www.btj.com/btjcgi/arvo/get_add_info.cgi?type=IMAGE&key=6598675235718681\n       _xKansikuva\n972    _aA1459779\n942 00 _05\n999    _c2820382\n       _d2820382',NULL),(8536594,'2016-10-07 22:11:15',0,'CATALOGUING','MODIFY',2822293,'biblio BEFORE=>LDR 01487nam a2200349   4500\n001     FF6122F6-3A5D-4E37-9C5F-BC3EABCDB188\n003     FI-Joro\n005     20160908011111.0\n008     030502s2003    fi ||||j |||| |||| |fin|c\n020    _a9515672376 (sid.)\n035    _aFF6122F6-3A5D-4E37-9C5F-BC3EABCDB188\n041 0  _afin\n084    _a58.12\n       _2ykl\n090    _a58.12\n090    _a58.12\n090    _a58.12\n245 00 _aTerve teille lintuset! /\n       _c[toimituskunta: Eeva Halonen, Leena Järvenpää, Arno Rautavaara] ; [lajitekstit: Arno Rautavaara] ; [valokuvat: Antti Leinonen ... et al.].\n260    _aHelsinki :\n       _bSatusiivet :\n       _bLasten parhaat kirjat,\n       _c2003.\n300    _a38 s. :\n       _bkuv. ;\n       _c27 cm.\n500    _aKansialanimeke: Lasten tietokirja linnuista.\n650  7 _alinnut\n       _2ysa\n700 1  _aHalonen, Eeva.\n700 1  _aJärvenpää, Leena.\n700 1  _aRautavaara, Arno.\n700 1  _aLeinonen, Antti.\n856 42 _uhttp://www.btj.com/btjcgi/arvo/get_add_info.cgi?type=PRES&key=adWP7QF109i252B1\n       _qTEXT\n       _zKuvaus\n856 42 _uhttp://www.btj.com/btjcgi/arvo/get_add_info.cgi?type=IMAGE&key=adWP7QF109i252B1\n       _qIMAGE\n       _zKansikuva\n904    _ap\n971    _aBTJ\n       _bT040206\n       _dKirjo 2004 : 2\n       _c20040206\n       _e25,83EUR\n       _f8%\n       _g10\n       _i29\n       _p3,6\n       _sACF-\n       _t021\n       _uhttp://www.btj.com/btjcgi/arvo/get_add_info.cgi?type=PRES&key=adWP7QF109i252B1\n       _xKuvaus\n       _uhttp://www.btj.com/btjcgi/arvo/get_add_info.cgi?type=IMAGE&key=adWP7QF109i252B1\n       _xKansikuva\n972    _aA0796268\n942 00 _05\n999    _c2822293\n       _d2822293',NULL);};
my $insertGroupSeparatorInsideQuotes2 = q{INSERT INTO `action_logs` VALUES (8536592,'2016-10-07 22:11:15',0,'CATALOGUING','MODIFY',2818677,'biblio',NULL),(8536593,'2016-10-07 22:11:15',0,'CATALOGUING','MODIFY',2820382,'biblio',NULL),(8536594,'2016-10-07 22:11:15',0,'CATALOGUING','MODIFY',2822293,'biblio',NULL);}."\n";
my ($tableName, $insertPrefix, $lines) = SQLAnon::decomposeInsertStatement($insertGroupSeparatorInsideQuotes2);
my ($colVal, $colMeta) = SQLAnon::decomposeValueGroup($lines->[0]);
#
=cut
use MySQL::Dump::Parser::XS;

open my $fh, '<:raw', 't/04-testdb.sql' or die $!;

my %rows;
my $parser = MySQL::Dump::Parser::XS->new;
while (my $line = <$fh>) {
    $line =~ s/\\/\\\\/g;
    my @rows  = $parser->parse($line);
    my $table = $parser->current_target_table();
    push @{ $rows{$table} } => @rows if ($table && @rows);
}

for my $table ($parser->tables()) {
    my @columns = $parser->columns($table);
    my $row     = $rows{$table};
    print "[$table] id:$row->{id}\n";
}