#!/usr/bin/perl

use strict;

$| = 1;

use lib './lib';
use t::lib::Test;
use Test::More tests => 9;
use DBR::Config::Scope;

my $dbr = setup_schema_ok( 'sorttest', undef, 'alpha');
my $schema = DBR::Config::Schema->new(handle => 'sorttest', session => $dbr->session);
my $instance = $schema->get_instance('master','alpha');
ok($instance, 'base instance Alpha found');

my $dbinfo = $dbr->connect('dbrconf')->select( -table => 'dbr_instances', -fields => 'instance_id schema_id class dbname username password host dbfile module handle readonly tag' )->[0];
ok($dbinfo, 'fetch instance (Alpha) data for cloning');


## Bravo instance ( testing schema->get_instance )

my $instance = $schema->get_instance( 'master', undef, 'bravo' );
ok(!$instance, 'instance Bravo has not been created yet');

my $r = $dbr->connect('dbrconf')->insert( -table => 'dbr_instances', -fields => { schema_id => ['d',$dbinfo->{schema_id}], map(($_, $dbinfo->{$_}), qw'class dbfile module'), handle => 'new', tag => 'bravo' } );
ok($r, 'Created instance Bravo)');

my $instance = $schema->get_instance( 'master', 'bravo' );
ok($instance, 'instance Bravo retrievable via schema->get_instance');


## Charlie instance ( testing dbr->connect )

my $r = $dbr->connect('dbrconf')->insert( -table => 'dbr_instances', -fields => { schema_id => ['d',$dbinfo->{schema_id}], map(($_, $dbinfo->{$_}), qw'class dbfile module'), handle => 'new', tag => 'charlie' } );
ok($r, 'Created instance Charlie');

my $dbrh = $dbr->connect( 'new', undef, 'charlie' );
ok($dbrh, 'instance Bravo retrievable via dbr->connect');
is ($dbrh->abc->all->count, 3, 'can use new connection');

1;

