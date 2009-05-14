package DBR::Common;

use strict;
use Time::HiRes;
my %TIMERS;

sub _uniq{
    my $self = shift;

    my %uniq;
    return grep{!$uniq{$_}++} @_;

}

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

      return $out;
}

sub _stopwatch{
      my $self = shift;
      my $label = shift;

      my ( $package, $filename, $line, $method ) = caller( 1 ); # First caller up
      my ($m) = $method =~ /([^\:]+)$/;

      if($label){

	    my $elapsed = Time::HiRes::time() - $TIMERS{$method};
	    my $seconds = sprintf('%.8f',$elapsed);
	    $self->_logDebug( "$m ($label) took $seconds seconds");
      }

      $TIMERS{ $method } = Time::HiRes::time(); # Logger could be slow

      return 1;
}
sub _error {
      my $self = shift;
      my $message = shift;

      my ( $package, $filename, $line, $method) = caller(1);
      if ($self->logger){
	    $self->logger->logErr($message,$method);
      }else{
	    print STDERR "DBR ERROR: $message ($method, line $line)\n";
      }
      return undef;
}

sub _logDebug{
      my $self = shift;
      my $message = shift;
      my ( $package, $filename, $line, $method) = caller(1);
      if ($self->logger){
	    $self->logger->logDebug($message,$method);
      }elsif($self->is_debug){
	    print STDERR "DBR DEBUG: $message\n";
      }
}
sub _logDebug2{
      my $self = shift;
      my $message = shift;
      my ( $package, $filename, $line, $method) = caller(1);
      if ($self->logger){
	    $self->logger->logDebug2($message,$method);
      }elsif($self->is_debug){
	    print STDERR "DBR DEBUG2: $message\n";
      }
}
sub _log{
      my $self = shift;
      my $message = shift;
      my ( $package, $filename, $line, $method) = caller(1);
      if ($self->logger){
	    $self->logger->log($message,$method);
      }else{
	    print STDERR "DBR: $message\n";
      }
      return 1;
}

sub logger   { $_[0]->{logger} }
sub is_debug { $_[0]->{debug}  }

1;
