#!perl -T

use strict;
use warnings;

#use Carp qw(confess); $SIG{__DIE__} = \&confess;
use Test::More tests => 8;

BEGIN {
    use_ok('DBI');
}

my $table = 'po_crash.po';
my $dbh;

# build table
{
    $dbh = DBI->connect(
        'dbi:PO:',
        undef,
        undef,
        {
            RaiseError => 1,
            PrintError => 0,
            AutoCommit => 1,
        },
    );
    isa_ok($dbh, 'DBI::db', 'connect');

    if (1) {
        open my $file, '>', 'trace_11.txt';
        $dbh->trace(4, $file);
    }

    my $result = $dbh->do(<<"EO_SQL");
        CREATE TABLE $table (obsolete INTEGER)
EO_SQL
    is($result, '0E0', 'create table');
    ok(-e $table, 'table file found');
}

# change header and line
{
    my $result = $dbh->do(<<"EO_SQL", undef, qw(comment_both msg_both));
        INSERT INTO $table (
            comment, msgid
        ) VALUES (?, ?)
EO_SQL
    is($result, 1, "change header and line");
}

# change id to undef
{
    my $result = $dbh->do(<<"EO_SQL", undef, undef, 'id_1');
        UPDATE $table
        SET    msgid=?
        WHERE  msgid=?
EO_SQL
    is($result, '0E0', 'change id to undef');
}

# destroy table
{
    my $result = $dbh->do(<<"EO_SQL");
        DROP TABLE $table
EO_SQL
    is($result, '-1', 'drop table');
    ok(! -e $table, 'table file deleted');
}