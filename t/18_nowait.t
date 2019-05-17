#!/usr/bin/env perl

use strict;
use warnings;

use lib './lib';
use t::lib::Test;
use Test::More;
use DBI::Const::GetInfoType;

my $resultset = setup_schema_ok('music')->connect('music')->album->all;
my $query = $resultset->[3];
my $conn = $query->instance->getconn;

{
    my $dbms_name = $conn->{dbh}->get_info($GetInfoType{SQL_DBMS_NAME});
    my $dbms_version = $conn->{dbh}->get_info($GetInfoType{SQL_DBMS_VER});

    like
        $query->sql,
        qr,SELECT\s+"album_id"\s+FROM\s+"album",i,
        "$dbms_name $dbms_version: nowait not set yet";

    $resultset->nowait(1);

    like
        $query->sql,
        qr,SELECT\s+"album_id"\s+FROM\s+"album",i,
        "$dbms_name $dbms_version: no nowait support";
}

{
    # Fake MySQL 5.7 database handle
    my $method = ref($conn->{dbh}) . '::get_info';
    no strict 'refs';
    no warnings;
    local *{$method} = sub {
        my ($pkg, $info_field) = @_;

        return 'MySQL'
            if $info_field == $GetInfoType{SQL_DBMS_NAME};

        return '5.7'
            if $info_field == $GetInfoType{SQL_DBMS_VER};

        return;
    };
    use strict 'refs';
    use warnings;

    my $dbms_name = $conn->{dbh}->get_info($GetInfoType{SQL_DBMS_NAME});
    my $dbms_version = $conn->{dbh}->get_info($GetInfoType{SQL_DBMS_VER});

    $resultset->nowait(1);
    my $regex = 'SELECT\s+/\*\+\s+MAX_EXECUTION_TIME\(' . DBR::ResultSet::MIN_MAX_EXECUTION_TIME . '\)\s+\*/\s+"album_id"\s+FROM\s+"album"';

    like
        $query->sql,
        qr,$regex,i,
        "$dbms_name $dbms_version: max execution time hint with min timeout";

    $resultset->nowait(100);

    like
        $query->sql,
        qr,SELECT\s+/\*\+\s+MAX_EXECUTION_TIME\(100\)\s+\*/\s+"album_id"\s+FROM\s+"album",i,
        "$dbms_name $dbms_version: max execution time hint with higher custom timeout";
}

done_testing();
