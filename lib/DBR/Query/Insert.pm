# The contents of this file are Copyright (c) 2010 Daniel Norman
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License as
# published by the Free Software Foundation.

###########################################
package DBR::Query::Insert;

use strict;
use base 'DBR::Query';
use Carp;

sub _params    { qw (fields valuesets tables where limit quiet_error) }
sub _reqparams { qw (fields valuesets tables) }

sub fields{
      my $self = shift;
      exists( $_[0] ) or return $self->{fields};

      my $fields = shift;
      ref($fields) eq 'ARRAY' or croak('fields must be an arrayref');
      scalar(@$fields) || croak('must provide at least one field');

      for (@$fields){
            ref($_) =~ /^DBR::Config::Field/ || croak('arguments must be Fields');
      }
      
      $self->{fields} = $fields;
      $self->{valuesets} = [];

      $self->_check_fields;

      return 1;
}

sub valuesets{
      my $self = shift;
      exists( $_[0] ) or return $self->{valuesets};

      my $valuesets = shift;
      ref($valuesets) eq 'ARRAY' or croak('valuesets must be an arrayref');
      scalar(@$valuesets) || croak('must provide at least one value');

      my $fieldcount = scalar(@{$self->fields});

      for my $valueset (@$valuesets){
            ref($valueset) eq 'ARRAY' or croak "valueset must be an arrayref";
            (scalar(@$valueset) == $fieldcount) || croak "Invalid number of values specified";

            for my $value (@$valueset) {
                  (ref($value) eq 'DBR::Query::Part::Value') or croak('arguments must be Values (' . ref($value) . ')');

                  # ideally we would check each value against the field offset to make sure that it matches
                  # but Query::Part::Set doesn't do this either, and it's not really an SQL injection risk
            }
      }

      $self->{valuesets} = $valuesets;

      $self->_check_fields;

      return 1;
}

sub _check_fields{
      my $self = shift;

      # Make sure we have sets for all required fields
      # It may be slightly more efficient to enforce this in ::Interface::Object->insert, but it seems more correct here.

      return 0 unless $self->{fields} && $self->{valuesets} && $self->{tables};

      my %fids = map { $_->field_id => 1 } grep { defined $_->field_id } @{ $self->{fields} };

      my $reqfields = $self->primary_table->req_fields();
      my @missing;
      foreach my $field ( grep { !$fids{ $_->field_id } } @$reqfields ){

            if ( defined ( my $v = $field->default_val ) ){
                  my $value = $field->makevalue( $v ) or croak "failed to build value object for " . $field->name;
                  push @{ $self->{fields} }, $field;

                  for my $valueset (@{$self->{valuesets}}){
                        push @$valueset, $value; # no need to clone this
                  }
            }else{
                  push @missing, $field;
            }

      }
      if(@missing){
	    croak "Invalid insert. Missing fields (" .
	    join(', ', map { $_->name } @missing) . ")";
      }
      $self->{_fields_checked} = 1;
}

sub _validate_self{
      my $self = shift;

      @{$self->{tables}} == 1 or croak "Must have exactly one table";
      $self->{fields} or croak "Must have at least one field";
      $self->{valuesets} or croak "Must have at least one valueset";
      
      $self->_check_fields unless $self->{_fields_checked};
      
      return 1;
}

sub sql{
      my $self = shift;

      my $conn   = $self->instance->connect('conn') or return $self->_error('failed to connect');
      my $sql;
      my $optimizer_hints = $self->optimizer_hints ? $self->optimizer_hints->sql($conn) : '';
      my $tables = join(',', map {$_->sql($conn)} @{$self->{tables}} );

      $sql = "INSERT INTO $optimizer_hints$tables (" . join (', ', map { $_->sql( $conn ) } @{$self->fields} ) . ') values ';

      my $ct = -1;
      for my $valueset (@{$self->valuesets}){
            $sql .= ($ct++ ? '' : ',') . '(' . join (',', map { $_->sql( $conn ) } @{$valueset} ) . ')';
      }

      $sql .= ' WHERE ' . $self->{where}->sql( $conn ) if $self->{where};
      $sql .= ' FOR UPDATE'                            if $self->{lock} && $conn->can_lock;
      $sql .= ' LIMIT ' . $self->{limit}               if $self->{limit};

      $self->_logDebug2( $sql );
      return $sql;
}

sub run{
      my $self = shift;
      my %params = @_;

      my $conn = $self->instance->connect('conn') or return $self->_error('failed to connect');

      $conn->quiet_next_error if $self->quiet_error;
      $conn->prepSequence() or confess 'Failed to prepare sequence';

      my $rows = $conn->do( $self->sql ) or return $self->quiet_error ? undef : $self->_error("Insert failed: $DBI::errstr");

      # Tiny optimization: if we are being executed in a void context, then we
      # don't care about the sequence value. save the round trip and reduce latency.
      return 1 if $params{void};

      my ($sequenceval) = $conn->getSequenceValue();

      return $sequenceval;

}

1;
