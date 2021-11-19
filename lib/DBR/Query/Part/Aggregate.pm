# the contents of this file are Copyright (c) 2009 Daniel Norman
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License as
# published by the Free Software Foundation.

###########################################
package DBR::Query::Part::Aggregate;

use strict;
use base 'DBR::Query::Part';

sub new {
      my ($package, $function, $field) = @_;

      return $package->_error("aggregate function $function not supported")
          unless $function =~ qr/^(
              AVG|
              BIT_AND|
              BIT_OR|
              BIT_XOR|
              COUNT|
              COUNT\(DISTINCT\)|
              GROUP_CONCAT|
              JSON_ARRAYAGG|
              JSON_OBJECTAGG|
              MAX|
              MIN|
              STD|
              STDDEV|
              STDDEV_POP|
              STDDEV_SAMP|
              SUM|
              VAR_POP|
              VAR_SAMP|
              VARIANCE|
          )$/xi;

      return $package->_error('field must be a Field object')
          unless ref($field) =~ /^DBR::Config::Field/; # Could be ::Anon

      my $self = [$function, $field];

      bless($self, $package);

      return $self;
}

sub sql {
    my ($self, $conn) = @_;

    return uc($self->[0]) eq 'COUNT(DISTINCT)'
        ? "COUNT(DISTINCT $self->[1])"
        : "$self->[0](" . $self->[1]->sql($conn) . ")";
}

sub _validate_self { 1 }

sub validate { 1 }

1;
