# the contents of this file are Copyright (c) 2009 Daniel Norman
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License as
# published by the Free Software Foundation.

###########################################
package DBR::Query::Part::OptimizerHints::MaxExecutionTime;

use strict;
use base 'DBR::Query::Part::OptimizerHints';

sub new {
    my ($package, $limit_milliseconds) = @_;

    $package->_error('positive execution limit (milliseconds) required')
        unless 0 + $limit_milliseconds > 0;

    return bless(\$limit_milliseconds, $package);
}

sub limit_milliseconds { return ${$_[0]} }

sub sql { return 'MAX_EXECUTION_TIME(' . $_[0]->limit_milliseconds . ')' }

# _validate_self doesn't get called unless the query part is provided at query
#  object creation, thus we validate in new
sub _validate_self { 1 }

1;
