# the contents of this file are Copyright (c) 2009 Daniel Norman
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License as
# published by the Free Software Foundation.

package DBR::Config::Instance;

use strict;
use DBI;
use base 'DBR::Common';
use DBR::Config::Schema;
use Carp;

my $GUID = 1;

#here is a list of the currently supported databases and their connect string formats
my %connectstrings = (
		      Mysql  => 'dbi:mysql:host=-hostname-;mysql_enable_utf8mb4=1',
		      Mysql_UDS => 'dbi:mysql:mysql_socket=[-hostname-];mysql_enable_utf8mb4=1',
		      SQLite => 'dbi:SQLite:dbname=-dbfile-',
		      Pg     => 'dbi:Pg:dbname=-database-;host=-hostname-',
		     );

my %CONCACHE;
my %INSTANCE_MAP;
my %SCHEMA_MAP;
my %INSTANCES_BY_GUID;


sub flush_all_handles {
      # can be run with or without an object
      my $cache = \%CONCACHE;

      foreach my $cachekey (keys %$cache){
	    my $conn = $cache->{ $cachekey };
	    if($conn){
		  $conn->disconnect();
		  delete $cache->{ $cachekey };
	    }
      }

      return 1;
}

sub lookup{
      my $package = shift;
      my %params = @_;

      my $self = {
		  session => $params{session}
		 };
      bless( $self, $package );

      return $self->_error('session is required') unless $self->{session};

      if( $params{guid} ){
	    $self->{guid} = $params{guid};
      }else{
	    my $handle = $params{handle} || return $self->_error('handle is required');
	    my $class  = $params{class}  || 'master';
	    my $tag    = $params{tag}    || $self->{session}->tag;
	    
            my $findit = sub {
                my $h = $INSTANCE_MAP{$handle} or return;

                return $h->{$tag}{$class} || $h->{$tag}{'*'} || $h->{''}{$class} || $h->{''}{'*'}; # handle aliases if there's no exact match
            };

            $self->{guid} = $findit->();
            if (!$self->{guid}) {
                __PACKAGE__->reload_instances( session => $params{session} );
                $self->{guid} = $findit->();
            }
            if (!$self->{guid}) {
                return $self->_error("No DB instance found for $handle-$class-$tag");
            }
      }

      $INSTANCES_BY_GUID{ $self->{guid} } or return $self->_error('no such guid');

      return $self;
}

sub reload_instances {
    my $package = shift;
    my %params = @_;

    for my $confguid (keys %INSTANCES_BY_GUID) {
        my $conf = $package->lookup( session => $params{session}, guid => $confguid ) or return $package->_error("Failed to fetch conf instance");
        next unless $conf->dbr_bootstrap;
        $package->load_from_db( parent_inst => $conf, session => $params{session} ) or return $package->_error("Failed to reload instances");
    }
}

sub guess_sibling {
    my $package = shift;
    my %params = @_;

    my $guid    = $params{guid};
    my $session = $params{session};

    return -1 if $params{guid} < 0;
    my $self = $package->lookup( session => $params{session}, guid => $params{guid} ) or return -1;

    my $sid = $params{schema_id};
    my $tag = $self->tag || $session->tag;
    my $class = $self->class;

    return $SCHEMA_MAP{$sid}{$tag}{$class} || $SCHEMA_MAP{$sid}{''}{$class} || -1;
}

sub is_colocated {
    my $package = shift;
    my $guid1 = shift;
    my $guid2 = shift;

    my $config1 = $INSTANCES_BY_GUID{$guid1};
    my $config2 = $INSTANCES_BY_GUID{$guid2};

    return $config1 && $config2 && _connectid($config1) eq _connectid($config2);
}

sub load_from_db{

      my( $package ) = shift;
      my %params = @_;

      my $self = {
		  session => $params{session},
		 };
      bless( $self, $package ); # Dummy object

      my $parent = $params{parent_inst} || return $self->_error('parent_inst is required');
      my $dbh = $parent->connect || return $self->_error("Failed to connect to (@{[$parent->handle]} @{[$parent->class]})");
      my $loaded = $INSTANCES_BY_GUID{ $parent->{guid} }{ loaded_instances } ||= [];

      return $self->_error('Failed to select instances') unless
	my $instrows = $dbh->select(
				    -table => 'dbr_instances',
                                    -where  => (@$loaded ? { instance_id => [ "d!", @$loaded ] } : undef),
				    -fields => 'instance_id schema_id class dbname username password host dbfile module handle readonly tag'
				   );

      my @instances;
      foreach my $instrow (@$instrows){

	    my $instance = $self->register(
					   session => $self->{session},
					   spec   => $instrow
					  ) || $self->_error("failed to load instance from database (@{[$parent->handle]} @{[$parent->class]})") or next;
	    push @instances, $instance;
            push @$loaded, $instrow->{instance_id};
      }

      return \@instances;
}

sub register { # basically the same as a new
      my( $package ) = shift;
      $package = ref( $package ) || $package;
      my %params = @_;


      my $self = {
		  session => $params{session}
		 };
      bless( $self, $package );

      return $self->_error( 'session is required'  ) unless $self->{session};

      my $spec = $params{spec} or return $self->_error( 'spec ref is required' );

      my $config = {
		    handle      => $spec->{handle}   || $spec->{name},
		    module      => $spec->{module}   || $spec->{type},
		    database    => $spec->{dbname}   || $spec->{database},
		    hostname    => $spec->{hostname} || $spec->{host},
		    user        => $spec->{username} || $spec->{user},
		    dbfile      => $spec->{dbfile},
		    tag         => $spec->{tag} || '',
		    password    => $spec->{password},
		    class       => $spec->{class}       || 'master', # default to master
		    instance_id => $spec->{instance_id} || '',
		    schema_id   => $spec->{schema_id}   || '',
		    allowquery  => $spec->{allowquery}  || 0,
		    readonly    => $spec->{readonly}    || 0,
		   };

      return $self->_error( 'module/type parameter is required'     ) unless $config->{module};
      return $self->_error( 'handle/name parameter is required'     ) unless $config->{handle};

      $config->{connectstring} = $connectstrings{$config->{module}} || return $self->_error("module '$config->{module}' is not a supported database type");
      if ($config->{module} eq 'Mysql' && $config->{hostname} =~ m|^/|) {
	    $config->{connectstring} = $connectstrings{Mysql_UDS};
      }

      my $connclass = 'DBR::Misc::Connection::' . $config->{module};
      return $self->_error("Failed to Load $connclass ($@)") unless eval "require $connclass";

      $config->{connclass} = $connclass;

      my $reqfields = $connclass->required_config_fields or return $self->_error('Failed to determine required config fields');

      foreach my $name (@$reqfields){
	    return $self->_error( $name . ' parameter is required' ) unless $config->{$name};
      }

      $config->{dbr_bootstrap} = $spec->{dbr_bootstrap}? 1:0;

      foreach my $key (keys %{$config}) {
	    $config->{connectstring} =~ s/-$key-/$config->{$key}/;
      }

      # Register or Reuse the guid
      my $guid = $INSTANCE_MAP{ $config->{handle} }{ $config->{tag} }{ $config->{class} } ||= $GUID++;
      $SCHEMA_MAP{ $config->{schema_id} }{ $config->{tag} }{ $config->{class} } = $guid;

      $INSTANCES_BY_GUID{ $guid } = $config;
      $self->{guid} = $config->{guid} = $guid;
      # Now we are cool to start calling accessors

      if ($spec->{alias}) {
	    $INSTANCE_MAP{ $spec->{alias} }{ $config->{tag} }{'*'} = $guid;
      }

      if ($config->{schema_id}){
	    DBR::Config::Schema->_register_instance(
						    schema_id => $config->{schema_id},
						    class     => $config->{class},
						    tag       => $config->{tag},
						    guid      => $guid,
						   ) or return $self->_error('failed to register table');
      }

      return( $self );
}


#######################################################################
############################                                          #
############################  All subs below here require an object   #
############################                                          #
#######################################################################


sub connect{
      my $self = shift;
      my $flag = shift || '';

      if (lc($flag) eq 'dbh') {
	    return $self->getconn->dbh;
      }elsif (lc($flag) eq 'conn') {
	    return $self->getconn;
      } else {
        return DBR::Handle->new(
            conn     => $self->getconn,
            session  => $self->{session},
            instance => $self,
        ) || confess 'Failed to create Handle object';
      }
}

sub _connectid {
    my $config = shift;

    return join "\0", $config->{connectstring}, ($config->{user} || ''), ($config->{password} || '');
}

sub getconn{
      my $self = shift;

      my $config = $INSTANCES_BY_GUID{ $self->{guid} };
      my $dedup  = _connectid($config);
      my $conn = $CONCACHE{ $dedup };

      # conn-ping-zoom!!
      return $conn if $conn && $conn->ping; # Most of the time, we are done right here

      if ($conn) {
	    $conn->disconnect();
	    $conn = $CONCACHE{ $dedup } = undef;
	    $self->_logDebug('Handle went stale');
      }

      # if we are here, that means either the connection failed, or we never had one

      $self->_logDebug2('getting a new connection');
      $conn = $self->_new_connection() or confess "Failed to connect to ${\$self->handle}, ${\$self->class}";

      $self->_logDebug2('Connected');

      return $CONCACHE{ $dedup } = $conn;
}

sub _new_connection{
      my $self = shift;

      my $config = $INSTANCES_BY_GUID{ $self->{guid} };
      my @params = ($config->{connectstring}, $config->{user}, $config->{password});

      my $dbh = DBI->connect(@params);
      unless ($dbh) {
          $self->_log("DBI error attempting to connect to db $config->{handle},$config->{class}: $DBI::errstr");
          return $self->_error("Error: Failed to connect to db $config->{handle},$config->{class}");
      }

      if($config->{connectstring} =~ /^dbi:mysql:/){
        $dbh->do("SET SESSION TRANSACTION ISOLATION LEVEL READ COMMITTED");
      }

      my $connclass = $config->{connclass};

      return $self->_error("Failed to create $connclass object") unless
	my $conn = $connclass->new(
				   session => $self->{session},
				   dbh     => $dbh
				  );

      return $conn;
}

sub is_readonly   { $INSTANCES_BY_GUID{ $_[0]->{guid} }->{readonly} }
sub handle        { $INSTANCES_BY_GUID{ $_[0]->{guid} }->{handle}   }
sub class         { $INSTANCES_BY_GUID{ $_[0]->{guid} }->{class}    }
sub tag           { $INSTANCES_BY_GUID{ $_[0]->{guid} }->{tag}    }
sub guid          { $INSTANCES_BY_GUID{ $_[0]->{guid} }->{guid}     }
sub module        { $INSTANCES_BY_GUID{ $_[0]->{guid} }->{module}   }
sub database      { $INSTANCES_BY_GUID{ $_[0]->{guid} }->{database}      }
sub dbr_bootstrap { $INSTANCES_BY_GUID{ $_[0]->{guid} }->{dbr_bootstrap} }
sub schema_id     { $INSTANCES_BY_GUID{ $_[0]->{guid} }->{schema_id} }
sub name          { return $_[0]->handle . ' ' . $_[0]->class }

#shortcut to fetch the schema object that corresponds to this instance
sub schema{
      my $self = shift;
      my %params = @_;

      my $schema_id = $self->schema_id || return ''; # No schemas here

      my $schema = DBR::Config::Schema->new(
					    session   => $self->{session},
					    schema_id => $schema_id,
					   ) || return $self->_error("failed to fetch schema object for schema_id $schema_id");

      return $schema;
}

1;
