package DBR::ResultSet::Empty;

use strict;
#use base 'DBR::Common';
use DBR::Misc::Dummy;
use Carp;
use constant ({
	       DUMMY => bless([],'DBR::Misc::Dummy')
	      });
sub new { bless( [], shift ) } # minimal reference

sub delete {croak "Mass delete is not allowed. No cookie for you!"}
sub each { 1 }
sub split { {} }
sub values { wantarray?():[]; }

sub dummy_record{ DUMMY }
sub hashmap_multi { wantarray?():{} }
sub hashmap_single{ wantarray?():{} }

sub limit    { shift }
sub lock     { }

sub next     { DUMMY }
sub where    { DUMMY }
sub count    { 0     }
sub order_by { DUMMY }
sub _execute { 1     }

sub TO_JSON { [] }

# Don't need to worry about nowait functionality on an empty resultset
sub can_nowait { 0, "Ignoring can_nowait on empty resultset" }
sub nowait { shift }
sub nowait_or_warn { shift }

1;
