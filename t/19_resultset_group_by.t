#!/usr/bin/perl

use strict;
use warnings;

$| = 1;

use lib './lib';
use t::lib::Test;
use Test::More;

my $dbr = setup_schema_ok('music');

my $dbh = $dbr->connect('music');
ok($dbh, 'dbr connect');

# Repeat the whole test twice to test both query modes (Unregistered and Prefetch)
for (1..2) {
    my $artist_rating = $dbh->album->where( 'artist.genre' => ['rock','blues'] )
        ->group_by('artist.genre')
        ->aggregate(['sum rating']);
    ok($artist_rating, 'retrieve artist rating');

    my $sth = $artist_rating->[3]->run;
    defined( $sth->execute ) or die 'failed to execute statement (' . $sth->errstr. ')';
    my $rows = $sth->fetchall_arrayref or die 'failed to execute statement (' . $sth->errstr . ')';
    use DDP; p($rows);
}

done_testing();
