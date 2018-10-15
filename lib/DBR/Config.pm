# the contents of this file are Copyright (c) 2009 Daniel Norman
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License as
# published by the Free Software Foundation.

package DBR::Config;

use strict;
use base 'DBR::Common';
use DBR::Config::Instance;
use DBR::Config::Schema;
use Carp;

# DBR::Config - Parse and register DBR configuration files.
#
# Config file syntax:
#
# * Each config file may contain multiple config specs, separated by lines
#   which start with three dashes.
# * Configuation directives consist of key-value pairs, separated by an equals
#   sign.
# * Comments are supported.  Everything following the first `#` symbol will be
#   ignored.
# * Leading and trailing whitespace will be stripped from all keys and values.
# * Multiple keys-value pairs may appear on a single line, separated by a
#   semicolon.
# * Keys and values may contain any character except `\n`, `=`, `#`, or `;`.
#   (Whether such liberal syntax was deliberate is uncertain.)
# * Keys are case-insensitive.

# Keep a record of which config files we have already read in and parsed
# successfully.  Avoid parsing files more than once.  (For efficiency?)
my %LOADED_FILES;

#    my $config = DBR::Config->new(
#        session => $session,  # DBR::Session
#    );
sub new {
  my( $package ) = shift;
  my %params = @_;
  my $self = {session => $params{session}};

  croak( 'session is required'  ) unless $self->{session};

  bless( $self, $package );

  return( $self );
}

#     my $succeeded = $config->load_file(
#         dbr  => $dbr,
#         file => '/path/to/config/file',
#     );
#
# Parse a config file and register its contents with this session.
#
# If the exact filepath has been seen before, skip the repeat parsing.
#
# If a section indicates that we should bootstrap DBR, do so.
#
# If a section has an invalid config, use Session-specific error handling.
sub load_file{
      my $self = shift;
      my %params = @_;
      my $dbr   = $params{'dbr'}   or return $self->_error( 'dbr parameter is required'  );
      my $file  = $params{'file'}  or return $self->_error( 'file parameter is required' );

      # Skip processing if we've seen this exact filepath before.
      if ($LOADED_FILES{$file}){
	    $self->_logDebug2("skipping already loaded config file '$file'");
	    return 1;
      }

      # First time seeing this filepath, so parse it.
      $self->_logDebug2("loading config file '$file'");
      my @conf;
      my $setcount = 0;
      open (my $fh, '<', $file) || return $self->_error("Failed to open '$file'");

      # Iterate through the lines of the file.
      while (my $row = <$fh>) {
	    if ($row =~ /^(.*?)\#/){ # strip everything after the first comment
		  $row = $1;
	    }

	    $row =~ s/(^\s*|\s*$)//g;# strip leading and trailing spaces
	    next unless length($row);

	    $conf[$setcount] ||= {};
	    if($row =~ /^---/){ # section divider. increment the count and skip this iteration
		  $setcount++;
		  next;
	    }

	    foreach my $part (split(/\s*\;\s*/,$row)){ # Semicolons are ok in lieu of newline cus I'm arbitrary like that.
		  my ($key,$val) = $part =~ /^(.*?)\s*=\s*(.*)$/;

		  $conf[$setcount]->{lc($key)} = $val;
	    }
      }
      close $fh;

      # Filter blank sections
      @conf = grep { scalar ( %{$_} ) } @conf;

      # For each section in the config file, attempt to register a config
      # instance for this session.
      my $count;
      foreach my $instspec (@conf){
	    $count++;

	    my $instance = DBR::Config::Instance->register(
							   dbr    => $dbr,
							   session => $self->{session},
							   spec   => $instspec
							  ) or $self->_error("failed to load DBR conf file '$file' (stanza #$count)") && next;
	    if($instance->dbr_bootstrap){
		  #don't bail out here on error
		  $self->load_dbconf(
				     dbr      => $dbr,
				     instance => $instance
				    ) || $self->_error("failed to load DBR config tables") && next;
	    }
      }

      # If we've made it this far, record that we've successfully parsed this
      # file.
      $LOADED_FILES{$file} = 1;

      return 1;
}

# When a section in a configuration file points to a config which is stored in
# the database, load that config and any associated Schemas.
#
# If the config loading fails, perform session-specific error handling.
#
# Always return true (unless an exception occurs, or unless provided invalid
# params).
sub load_dbconf{
      my $self  = shift;
      my %params = @_;

      my $dbr         = $params{'dbr'}      or return $self->_error( 'dbr parameter is required'    );
      my $parent_inst = $params{'instance'} or return $self->_error( 'instance parameter is required' );

      # Attempt to load the config from the database which is specified in the
      # file.
      $self->_error("failed to create instance handles") unless
	my $instances = DBR::Config::Instance->load_from_db(
							    session   => $self->{session},
							    dbr      => $dbr,
							    parent_inst => $parent_inst
							   );

      # Load any Schemas which have an ID specified in the database config.
      my %schema_ids;
      map {$schema_ids{ $_->schema_id } = 1 } @$instances;
      if(%schema_ids){
	    $self->_error("failed to create schema handles") unless
	      my $schemas = DBR::Config::Schema->load(
						      session    => $self->{session},
						      schema_id => [keys %schema_ids],
						      instance  => $parent_inst,
						     );
      }

      return 1;
}

1;
