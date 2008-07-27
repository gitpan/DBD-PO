#!perl -T

use strict;
use warnings;

use lib qw(./t/lib);
use DBD_PO_Test_Defaults;

use Test::More tests => 22;

BEGIN {
    use_ok('DBI');
}

# build table
my $dbh = DBI->connect(
    "dbi:PO:f_dir=$DBD_PO_Test_Defaults::PATH",
    undef,
    undef,
    {
        RaiseError => 1,
        PrintError => 0,
        AutoCommit => 1,
    },
);
isa_ok($dbh, 'DBI::db', 'connect');

if ($DBD_PO_Test_Defaults::TRACE) {
    open my $file, '>', DBD_PO_Test_Defaults::trace_file_name();
    $dbh->trace(4, $file);
}

# create table
sub create_table {
    my $param = {table_number => shift};

    my $dbh = $param->{dbh} = DBI->connect(
        "dbi:PO:f_dir=$DBD_PO_Test_Defaults::PATH",
        undef,
        undef,
        {
            RaiseError => 1,
            PrintError => 0,
            AutoCommit => 1,
        },
    );
    isa_ok($dbh, 'DBI::db', "connect $param->{table_number}");

    @{$param}{qw(table table_file)} = (
        $DBD_PO_Test_Defaults::TABLE_12,
        $DBD_PO_Test_Defaults::FILE_12,
    );
    for my $name (@{$param}{qw(table table_file)}) {
        $name =~ s{\?}{$param->{table_number}}xms;
    }

    my ($table, $table_file) = @{$param}{qw(table table_file)};

    my $result = $dbh->do(<<"EO_SQL");
        CREATE TABLE $table (
            msgid VARCHAR,
            msgstr VARCHAR
        )
EO_SQL
    is($result, '0E0', "create table ($table)");
    ok(-e $table_file, "table file found ($table_file)");

    return $param;
}

sub create {
    my $param = shift;

    my ($table, $table_file) = @{$param}{qw(table table_file)};

    my $result = $dbh->do(<<"EO_SQL");
        CREATE TABLE $table (
            msgid  VARCHAR,
            msgstr VARCHAR
        )
EO_SQL
    is($result, '0E0', "create table $table");
    ok(-e $table_file, "table $table_file file found");

    return $param;
}

sub insert_header {
    my $param = shift;

    my $table = $param->{table};

    my $msgstr = $dbh->func(undef, 'build_header_msgstr');
    my $result = $dbh->do(<<"EO_SQL", undef, $msgstr);
        INSERT INTO $table (
            msgstr
        ) VALUES (?)
EO_SQL
    is($result, 1, "insert header into table $table");

    return $param;
}

sub insert_line {
    my $param = shift;

    my $table = $param->{table};

    my $result = $dbh->do(<<"EO_SQL", undef, $table, $table);
        INSERT INTO $table (
            msgid,
            msgstr
        ) VALUES (?, ?)
EO_SQL
    is($result, 1, "insert line into table $table");

    return $param;
}

sub prepare {
    my $param = shift;

    my $table = $param->{table};

    my $sth = $param->{sth} = $dbh->prepare(<<"EO_SQL");
        SELECT msgstr
        FROM   $table
        WHERE  msgid=?
EO_SQL
    isa_ok($sth, 'DBI::st', "prepare $table");

    return $param;
}

sub execute {
    my $param = shift;

    my $table = $param->{table};

    my $result = $param->{sth}->execute($table);
    is($result, 1, "insert $table");

    return $param;
}

sub fetch {
    my $param = shift;

    my $table = $param->{table};

    my ($result) = $param->{sth}->fetchrow_array();
    is($result, $table, "fetch $table");

    return $param;
}

sub drop_table {
    my $param = shift;

    my ($table, $table_file) = @{$param}{qw(table table_file)};

    my $result = $dbh->do(<<"EO_SQL");
        DROP TABLE $table
EO_SQL
    is($result, '-1', "drop table $table");
    ok(! -e $table_file, "table file $table_file deleted");

    return;
}

() = map {
         drop_table($_);
     }
     map {
         fetch($_);
     }
     map {
         execute($_);
     }
     map {
         prepare($_);
     }
     map {
         insert_line($_);
     }
     map {
         insert_header($_);
     }
     map {
         create_table($_);
     } 1 .. 2;