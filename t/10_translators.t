#!/usr/bin/perl

use strict;
use warnings;
no warnings 'uninitialized';

$| = 1;

use lib './lib';
use t::lib::Test;
use Test::More;

my $dbr = setup_schema_ok('music');

my $dbh = $dbr->connect('music');
ok($dbh, 'dbr connect');
my $rv;

my %ALBUMDATES = (
		   'Artist A' => 924625200,
		   'Artist B' => 946684800,
		  );

my $artists = $dbh->artist->all();
ok( defined($artists) , 'select all artists');

my $one_artist;
while (my $artist = $artists->next()) {
    $one_artist ||= $artist;

    my ($refdate,$datetime);
    ok ( $refdate  =  $ALBUMDATES{$artist->name} , 'datetime - reference date');
    ok ( $datetime =  $artist->date_founded,       'datetime - date_founded ' );
    ok ( $datetime == $refdate,                    'date verification');
    diag($datetime);
}

ok ( $one_artist->date_founded('2001-02-03 04:05:06'),    'datetime - update' );
ok ( $one_artist->date_founded('midnight Last Tuesday'),  'datetime - update' );
ok ( $one_artist->date_founded('next sunday'),  'datetime - update' );

my $expected_unixtime = 981173106;
ok ( $one_artist->date_founded('2001-02-03T04:05:06'), 'datetime - update w/ iso8601 (no tz)' );
is (
    $one_artist->date_founded->unixtime,
    $expected_unixtime,
    'datetime recorded properly from iso8601 (no tz)',
);

ok (
    $one_artist->date_founded('2001-02-03T04:05:06-00:00'),
    'datetime - update w/ iso8601 (w/ utc tz)',
);
is (
    $one_artist->date_founded->unixtime,
    $expected_unixtime,
    'datetime recorded properly from iso8601 (w/ utc tz)',
);

ok (
    $one_artist->date_founded('2001-02-02T21:05:06-07:00'),
    'datetime - update w/ iso8601 (w/ pdt tz)',
);
is (
    $one_artist->date_founded->unixtime,
    $expected_unixtime,
    'datetime recorded properly from iso8601 (w/ pdt tz)',
);

ok (
    $one_artist->date_founded('2001-02-02T21:05:06-0700'),
    'datetime - update w/ iso8601 (w/ no-colon tz)',
);
is (
    $one_artist->date_founded->unixtime,
    $expected_unixtime,
    'datetime recorded properly from iso8601 (w/ no-colon tz)',
);

ok (
    $one_artist->date_founded('2001-02-03T04:05:06Z'),
    'datetime - update w/ iso8601 (w/ zulu tz)',
);
is (
    $one_artist->date_founded->unixtime,
    $expected_unixtime,
    'datetime recorded properly from iso8601 (w/ zulu tz)',
);

done_testing();
