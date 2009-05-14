# the contents of this file are Copyright (c) 2009 Daniel Norman
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License as
# published by the Free Software Foundation.

package DBR::Config::Field;

use strict;
use base 'DBR::Config::Field::Common';
use DBR::Query::Value;
use DBR::Config::Table;

my %FIELDS_BY_ID;

#HERE HERE HERE - This is ugly... clean it up
my %datatypes = (
		 bigint    => { id => 1, numeric => 1, bits => 64},
		 int       => { id => 2, numeric => 1, bits => 32},
		 mediumint => { id => 3, numeric => 1, bits => 24},
		 smallint  => { id => 4, numeric => 1, bits => 16},
		 tinyint   => { id => 5, numeric => 1, bits => 8},
		 bool      => { id => 6, numeric => 1, bits => 1},
		 float     => { id => 7, numeric => 1, bits => 1},
		 double    => { id => 8, numeric => 1, bits => 1},
		 varchar   => { id => 9 },
		 char      => { id => 10 },
		 text      => { id => 11 },
		 mediumtext=> { id => 12 },
		 blob      => { id => 13 },
		 longblob  => { id => 14 },
		 mediumblob=> { id => 15 },
		 tinyblob  => { id => 16 },
		 enum      => { id => 17 }, # I loathe mysql enums
		);

my %datatype_lookup = map { $datatypes{$_}->{id} => {%{$datatypes{$_}}, handle => $_ }} keys %datatypes;


sub load{
      my( $package ) = shift;
      my %params = @_;

      my $self = { logger => $params{logger} };
      bless( $self, $package ); # Dummy object

      my $dbr    = $params{dbr}    || return $self->_error('dbr is required');
      my $handle = $params{handle} || return $self->_error('handle is required');
      my $class  = $params{class}  || return $self->_error('class is required');

      my $table_ids = $params{table_id} || return $self->_error('table_id is required');
      $table_ids = [$table_ids] unless ref($table_ids) eq 'ARRAY';


      my $dbh = $dbr->connect($handle,$class) || return $self->_error("Failed to connect to '$handle','$class'");

      return $self->_error('Failed to select fields') unless
	my $fields = $dbh->select(
				  -table => 'dbr_fields',
				  -fields => 'field_id table_id name field_type is_nullable is_signed is_pkey is_enum enum_param max_value',
				  -where  => { table_id => ['d in',@$table_ids] },
				 );

      foreach my $field (@$fields){

	    DBR::Config::Table->_register_field(
						table_id => $field->{table_id},
						name     => $field->{name},
						field_id => $field->{field_id},
					       ) or return $self->_error('failed to register field');
	    $FIELDS_BY_ID{ $field->{field_id} } = $field;
      }

      return 1;
}


sub new {
      my $package = shift;
      my %params = @_;
      my $self = {
		  dbrh     => $params{dbrh},
		  logger   => $params{logger},
		  field_id => $params{field_id},
		 };

      bless( $self, $package );

      return $self->_error('field_id is required') unless $self->{field_id};
      return $self->_error('dbrh object must be specified')   unless $self->{dbrh};

      return( $self );
}

sub makevalue{ # shortcut function?
      my $self = shift;
      my $value = shift;

      return DBR::Query::Value->new(
				    dbrh   => $self->{dbrh},
				    value  => $value,
				    is_number => $self->is_numeric,
				    field  => $self,
				   );# or return $self->_error('failed to create value object');

}

sub field_id { $_[0]->{field_id} }
sub table_id { $FIELDS_BY_ID{  $_[0]->{field_id} }->{table_id}    };
sub name     { $FIELDS_BY_ID{  $_[0]->{field_id} }->{name}    };
sub is_pkey  { $FIELDS_BY_ID{  $_[0]->{field_id} }->{is_pkey} }
sub table    {
      my $self = shift;

      return DBR::Config::Table->new(
				     dbrh     => $self->{dbrh},
				     logger   => $self->{logger},
				     table_id => $FIELDS_BY_ID{  $_[0]->{field_id} }->{table_id}
				    );
}

sub is_numeric{
      my $field = $FIELDS_BY_ID{ $_[0]->{field_id} };
      return $datatype_lookup{ $field->{field_type} }->{numeric} ? 1:0;
}

1;
