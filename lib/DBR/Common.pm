package DBR::Common;

use strict;
use Carp;

my %TIMERS;

#     my @unique = $obj->_uniq(@list);
#
# Return all the unique elements of a list, as a list.
#
# Comparison is done through stringification, with the exception of `undef`.
sub _uniq{
    my $self = shift;
    my $has_undef;
    my %uniq;
    return grep{ defined($_)?(  !$uniq{$_}++  ):(  !$has_undef++  ) } @_;
}

#     my @elems = $obj->_split($string);
#     my @same  = $obj->_split(\@elems);
#
# Split an input string on whitespace.  If the input is an array ref, return
# the elements of the referenced array.
#
# Returns an array in list context, or an arrayref in scalar context.
sub _split{
      my $self = shift;
      my $value = shift;

      my $out;
      if(ref($value)){
	    $out = $value;
      }else{
	    $value =~ s/^\s*|\s*$//g;
	    $out = [ split(/\s+/,$value) ];
      }

      return wantarray? (@$out): $out;
}

#      # @nums = (1, 2, 3, 4, 5, 6);
#      my @nums = $obj->_arrayify([1, 2, 3], [4, 5, 6]);
#
# Given a list, expand any arrayrefs, flattening by one level.
#
# Returns an array in list context, or an arrayref in scalar context.
sub _arrayify{
      my $self = shift;
      my @out = map { ref($_) eq 'ARRAY' ? (@$_) : ($_) } @_;
      return wantarray? (@out) : \@out;
}

# returns true if all elements of Arrayref A (or single value) are present in arrayref B
sub _b_in{
      my $self = shift;
      my $value1 = shift;
      my $value2 = shift;
      $value1 = [$value1] unless ref($value1);
      $value2 = [$value2] unless ref($value2);
      return undef unless (ref($value1) eq 'ARRAY' && ref($value2) eq 'ARRAY');
      my %valsA = map {$_ => 1} @{$value2};
      my $results;
      foreach my $val (@{$value1}) {
            unless ($valsA{$val}) {
                  return 0;
            }
      }
      return 1;
}

sub _log       {
      my $s = shift->_session or return 1;
      $s->_log( shift, 'INFO'  );
      return 1
}
sub _logDebug  {
      my $s = shift->_session or return 1;
      $s->_log( shift, 'DEBUG'  );
      return 1
}
sub _logDebug2  {
      my $s = shift->_session or return 1;
      $s->_log( shift, 'DEBUG2'  );
      return 1
}
sub _logDebug3  {
      my $s = shift->_session or return 1;
      $s->_log( shift, 'DEBUG3'  );
      return 1
}

sub _warn       {
      my $s = shift->_session or return 1;
      $s->_log( shift, 'WARN'  );
      return 1
}

sub _error     {
    my $s = shift->_session;
    my $message = shift;

    if($s){
	$s->_log( $message, 'ERROR' );
    }else{
	print STDERR "DBR ERROR: $message\n";
    }
    
    if( $s && $s->use_exceptions ){
	local $Carp::CarpLevel = 1;
	croak $message;
    }
    
    return undef;
}

sub _session { $_[0]->{session} }

1;
