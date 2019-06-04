# the contents of this file are Copyright (c) 2009 Daniel Norman
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License as
# published by the Free Software Foundation.

###########################################
package DBR::Query::Part::OptimizerHints;

use strict;
use base 'DBR::Query::Part';

sub new {
    my $package = shift;

    foreach my $hint (@_) {
        _validate_hint($package, $hint);
    }

    return bless([@_], $package);
}

sub push {
    my ($self, $hint) = @_;

    $self->children($self->children, $hint);

    return $self;
}

sub children {
    my ($self, @hints_to_set) = @_;

    if (@hints_to_set) {
        _validate_hint($self, $_) for @hints_to_set;

        @$self = @hints_to_set;
    }

    return @$self;
}

sub sql {
    my ($self, $conn) = @_;

    return '/*+ ' . join(' ', map { $_->sql($conn) } $self->children) . ' */ ';
}

sub _validate_hint {
    my ($package_or_self, $hint) = @_;

    ref($hint) =~ /^DBR::Query::Part::OptimizerHints::/
        or $package_or_self->_error("Must be an optimizer hint type");

    return;
}

1;
