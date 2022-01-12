#!/usr/bin/env perl

use strict;
use warnings;

use lib './lib';
use t::lib::Test;
use Test::More;

my $resultset = setup_schema_ok('music')
    ->connect('music')
    ->album
    ->where( artist_id => [1, 2], name => ['bar', 'baz']);
my $select_query = $resultset->[3];

like
    $select_query->sql,
    qr|^SELECT\s+"album_id"\s+FROM\s+"album"\s+WHERE\s+"artist_id"\s+IN\s+\(1,\s*2\)\s+AND\s+"name"\s+IN\s+\('bar',\s*'baz'\)$|i,
    "select without force index";

my $update_query = $resultset->set( name => "foo", -return_update_ref => 1 );

like
    $update_query->sql,
    qr|^UPDATE\s+"album"\s+SET\s+"name"\s+=\s+'foo'\s+WHERE\s+"artist_id"\s+IN\s+\(1,\s*2\)\s+AND\s+"name"\s+IN\s+\('bar',\s*'baz'\)$|i,
    "select without force index";

my $index_name = 'album_artist_name';
$resultset->force_index($index_name);

like
    $select_query->sql,
    qr|^SELECT\s+"album_id"\s+FROM\s+"album"\s+INDEXED BY\s+"$index_name"\s+WHERE\s+"artist_id"\s+IN\s+\(1,\s*2\)\s+AND\s+"name"\s+IN\s+\('bar',\s*'baz'\)$|i,
    "select with force index";

my $update_force_index_query = $resultset->set( name => "foo", -return_update_ref => 1 );

like
    $update_force_index_query->sql,
    qr|^UPDATE\s+"album"\s+INDEXED BY\s+"$index_name"\s+SET\s+"name"\s+=\s+'foo'\s+WHERE\s+"artist_id"\s+IN\s+\(1,\s*2\)\s+AND\s+"name"\s+IN\s+\('bar',\s*'baz'\)$|i,
    "update with force index";

done_testing();
