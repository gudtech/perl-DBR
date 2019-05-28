#!/usr/bin/perl

use strict;
use warnings;
no warnings 'uninitialized';

$| = 1;

use lib './lib';
use t::lib::Test;
use Test::More;
use Test::Exception;

my $dbr = setup_schema_ok({ schema => 'music', use_exceptions => 1 });

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

throws_ok { $dbh->album->where( rating => 501 )->next }
    qr/invalid value/i, 'query throws on non-existent enum id';

throws_ok { $dbh->album->where( rating => 'gobbledygook' )->next }
    qr/invalid value/i, 'query throws on non-existent enum handle';

throws_ok { $dbh->album->where( rating => 10 )->next }
    qr/invalid value/i, 'query throws on non-mapped enum id';

throws_ok { $dbh->album->where( rating => 'blues' )->next }
    qr/invalid value/i, 'query throws on non-mapped enum handle';

my $album = $dbh->album->where( rating => 'fair' )->next;
is $album->rating->handle, 'fair', 'query by enum handle';

$album = $dbh->album->where( rating => 500 )->next;
is $album->rating->handle, 'fair', 'query by enum id';

$album->rating('sucks');
is $album->rating->handle, 'sucks', 'set enum with handle';

$album->rating(600);
is $album->rating->handle, 'poor', 'set enum with id';

throws_ok { $album->rating(501) }
    qr/invalid value/i, 'set throws on non-existent enum id';

throws_ok { $album->rating('gobbledygook') }
    qr/invalid value/i, 'set throws on non-existent enum handle';

throws_ok { $album->rating(10) }
    qr/invalid value/i, 'set throws on non-mapped enum id';

throws_ok { $album->rating('blues') }
    qr/invalid value/i, 'set throws on non-mapped enum handle';

done_testing();
