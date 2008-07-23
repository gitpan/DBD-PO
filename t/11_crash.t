#!perl -T

use strict;
use warnings;

use lib qw(./t/lib);
use DBD_PO_Test_Defaults;

use Test::More tests => 8;

BEGIN {
    use_ok('DBI');
}

my $dbh;

# build table
{
    $dbh = DBI->connect(
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

    my $result = $dbh->do(<<"EO_SQL");
        CREATE TABLE $DBD_PO_Test_Defaults::TABLE_1X (obsolete INTEGER)
EO_SQL
    is($result, '0E0', 'create table');
    ok(-e $DBD_PO_Test_Defaults::FILE_1X, 'table file found');
}

# change header and line
{
    my $result = $dbh->do(<<"EO_SQL", undef, qw(comment_both msg_both));
        INSERT INTO $DBD_PO_Test_Defaults::TABLE_1X (
            comment, msgid
        ) VALUES (?, ?)
EO_SQL
    is($result, 1, "change header and line");
}

# change id to undef
{
    my $result = $dbh->do(<<"EO_SQL", undef, undef, 'id_1');
        UPDATE $DBD_PO_Test_Defaults::TABLE_1X
        SET    msgid=?
        WHERE  msgid=?
EO_SQL
    is($result, '0E0', 'change id to undef');
}

# destroy table
{
    my $result = $dbh->do(<<"EO_SQL");
        DROP TABLE $DBD_PO_Test_Defaults::TABLE_1X
EO_SQL
    is($result, '-1', 'drop table');
    ok(! -e $DBD_PO_Test_Defaults::FILE_1X, 'table file deleted');
}
