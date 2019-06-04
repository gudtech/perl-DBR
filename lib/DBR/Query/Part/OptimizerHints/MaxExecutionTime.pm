# the contents of this file are Copyright (c) 2009 Daniel Norman
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License as
# published by the Free Software Foundation.

###########################################
package DBR::Query::Part::OptimizerHints::MaxExecutionTime;

use strict;

=head1 NAME

DBR::Query::Part::OptimizerHints::MaxExecutionTime

=head1 SYNOPSIS

Support for MAX_EXECUTION_TIME optimizer hint that limits the time that MySQL
will spend executing a query before throwing an error.  Generally useful if
you don't want to wait for locks to resolve.

=cut

use base 'DBR::Query::Part::OptimizerHints';

=head1 CONSTRUCTOR

=head2 new($millisecond_limit)

Create hint with C<$millisecond_limit> max execution time limit.

=cut

sub new {
    my ($package, $millisecond_limit) = @_;

    $package->_error('positive execution limit (milliseconds) required')
        unless 0 + $millisecond_limit > 0;

    return bless(\$millisecond_limit, $package);
}

=head2 sql

Generate SQL for this optimizer hint.

=cut

sub sql { return 'MAX_EXECUTION_TIME(' . _millisecond_limit($_[0]) . ')' }

sub _millisecond_limit { return ${$_[0]} }

# _validate_self doesn't get called unless the query part is provided at query
#  object creation, thus we validate in new
sub _validate_self { 1 }

1;
