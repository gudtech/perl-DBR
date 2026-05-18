package DBR::Misc::DBI::Compat;

# DBI RootClass that restores DBD::mysql 4.036 behavior: all values returned
# by fetch methods are string scalars (SVp_POK), regardless of MySQL column type.
#
# Required because DBD::mysql 4.050 returns IV/NV scalars for numeric columns,
# changing JSON::XS output from quoted strings ("42") to bare numbers (42).
# Remove this shim once all consumers are verified safe with bare-number encoding.

package DBR::Misc::DBI::Compat::db;
use parent -norequire, 'DBI::db';

package DBR::Misc::DBI::Compat::st;
use parent -norequire, 'DBI::st';

sub fetchrow_arrayref {
    # DBD::mysql returns a reused internal row buffer whose AV is flagged
    # SvREADONLY, so assigning back into @$row dies. Build a fresh arrayref.
    my $row = $_[0]->SUPER::fetchrow_arrayref;
    return undef unless $row;
    return [ map { defined $_ ? "$_" : $_ } @$row ];
}

*fetch = \&fetchrow_arrayref;

sub fetchrow_array {
    my @row = $_[0]->SUPER::fetchrow_array;
    return map { defined $_ ? "$_" : $_ } @row;
}

sub fetchrow_hashref {
    my $row = $_[0]->SUPER::fetchrow_hashref(@_[1..$#_]);
    return undef unless $row;
    $row->{$_} = "$row->{$_}" for grep { defined $row->{$_} } keys %$row;
    return $row;
}

sub fetchall_arrayref {
    my $self  = shift;
    my $slice = $_[0];
    my $rows  = $self->SUPER::fetchall_arrayref(@_);
    return $rows unless $rows && @$rows;
    if ( ref($slice) eq 'HASH' ) {
        # Hash slot assignment replaces the SV, so in-place is safe here.
        for my $row (@$rows) {
            $row->{$_} = "$row->{$_}" for grep { defined $row->{$_} } keys %$row;
        }
        return $rows;
    }
    # Row AVs may be SvREADONLY (see fetchrow_arrayref); build fresh arrayrefs.
    return [ map { [ map { defined $_ ? "$_" : $_ } @$_ ] } @$rows ];
}

sub fetchall_hashref {
    my ($self, $key_field) = @_;
    my $result = $self->SUPER::fetchall_hashref($key_field);
    return $result unless $result;
    for my $row (values %$result) {
        $row->{$_} = "$row->{$_}" for grep { defined $row->{$_} } keys %$row;
    }
    return $result;
}

1;
