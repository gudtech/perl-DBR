# the contents of this file are Copyright (c) 2009 Daniel Norman
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License as
# published by the Free Software Foundation.

###########################################
package DBR::Query::Part::OptimizerHints::MaxExecutionTime;

use strict;
use base 'DBR::Query::Part::OptimizerHints';

sub new {
    my ($package, $millisecond_limit) = @_;

    $package->_error('positive execution limit (milliseconds) required')
        unless 0 + $millisecond_limit > 0;

    return bless(\$millisecond_limit, $package);
}


sub sql { return 'MAX_EXECUTION_TIME(' . _millisecond_limit($_[0]) . ')' }

sub _millisecond_limit { return ${$_[0]} }

# _validate_self doesn't get called unless the query part is provided at query
#  object creation, thus we validate in new
sub _validate_self { 1 }

1;
