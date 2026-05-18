#!/usr/bin/perl

# Regression test for ROP-9213: DBR::Misc::DBI::Compat must not write back
# into the row buffer returned by SUPER::fetchrow_arrayref, because some
# DBD drivers (notably DBD::mysql) flag those scalars SvREADONLY.

use strict;
use warnings;
$| = 1;

use Test::More tests => 7;

# Fake DBI::st parent that hands back arrayrefs whose AV is flagged
# SvREADONLY, mimicking DBD::mysql's reused-internal-buffer behavior.
# Compat::st uses `use parent -norequire, 'DBI::st'`, so we can populate
# DBI::st freely without actually loading DBI.
{
    package DBI::st;
    our @row_queue;
    sub fetchrow_arrayref {
        return undef unless @row_queue;
        my $row = shift @row_queue;
        Internals::SvREADONLY(@$row, 1);
        return $row;
    }
    sub fetchall_arrayref {
        my @out;
        while (my $r = DBI::st::fetchrow_arrayref()) { push @out, $r }
        return \@out;
    }
}

use_ok('DBR::Misc::DBI::Compat');

my $sth = bless {}, 'DBR::Misc::DBI::Compat::st';

# fetchrow_arrayref: must survive read-only elements and stringify defined values
@DBI::st::row_queue = ([1, 2, 'three'], [undef, 'x']);

my $r1 = eval { $sth->fetchrow_arrayref };
is($@, '', 'fetchrow_arrayref does not die on read-only row buffer');
is_deeply($r1, ['1', '2', 'three'], 'defined values stringified');

my $r2 = eval { $sth->fetchrow_arrayref };
is_deeply($r2, [undef, 'x'], 'undef preserved, defined stringified');

# fetchall_arrayref (array-slice path): same read-only safety
@DBI::st::row_queue = ([42, 'a'], [99, 'b']);
my $all = eval { $sth->fetchall_arrayref };
is($@, '', 'fetchall_arrayref does not die on read-only row buffers');
is_deeply($all, [['42','a'],['99','b']], 'all rows stringified');

# Returned arrayref must itself be writable (not the SUPER buffer)
eval { $all->[0][0] = 'mutable' };
is($@, '', 'returned row is a fresh, writable arrayref');
