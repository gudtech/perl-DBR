#!/usr/bin/perl

# Test that everything compiles, so the rest of the test suite can
# load modules without having to check if it worked.

use strict;
use warnings;
BEGIN {
	$|  = 1;
}

use Test::More tests => 11;

use_ok('DBR::Common');

my $obj = MyCommon->new;

# _uniq
{
    my @input = (1, 1, 2, 1, 3, 4, 5, 5, 6, 0);
    my @expected = (0 .. 6);
    my @got = sort($obj->_uniq(@input));
    is_deeply(\@got, \@expected, "_uniq numbers");
    my $count = $obj->_uniq(@input);
    is($count, scalar @expected, "_uniq returns count in scalar context");
}
{
    my @input = qw(A B C D E E F G);
    my @expected = ('A' .. 'G');
    my @got = sort($obj->_uniq(@input));
    is_deeply(\@got, \@expected, "_uniq letters");
}
{
    my @got = $obj->_uniq('', undef, 0, ' ', undef, ' ');
    is(@got, 4, '_uniq - Various forms of false');
}

# _split
{
    my $input = ' fee fie fo fum ';
    my @expected = qw( fee fie fo fum );
    my @got = $obj->_split($input);
    is_deeply(\@got, \@expected, '_split string');
    my @dupes = $obj->_split(\@got);
    is_deeply(\@dupes, \@expected, '_split arrayref returns elems');
    my $got = $obj->_split($input);
    is_deeply($got, \@expected, '_split returns arrayref in scalar context');
}

# _arrayify
{
    my @input = ([1 .. 3], [4 .. 6]);
    my @expected = 1 .. 6;
    my @got = $obj->_arrayify(@input);
    is_deeply(\@got, \@expected, '_arrayify two arrayrefs');
    my $got = $obj->_arrayify(@input);
    is_deeply($got, \@expected, '_arrayify returns arrayref in scalar context');
    my $same = $obj->_arrayify(\@input);
    is_deeply($same, \@input, '_arrayify only flattens one level');
}

package MyCommon;
BEGIN{ our @ISA = qw( DBR::Common ) }

# Trivial test-only subclass.

sub new {
    return bless {}, __PACKAGE__;
}
