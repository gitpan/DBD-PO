#!perl -T

use strict;
use warnings;

use lib qw(./t/lib);
use DBD_PO_Test_Defaults;

use Test::More tests => 4;

BEGIN {
    use_ok('DBI');
}

my $dbh;

# connext
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
}

# destroy table
{
    my $result = $dbh->do(<<"EO_SQL");
        DROP TABLE $DBD_PO_Test_Defaults::TABLE_0X
EO_SQL
    is($result, '-1', 'drop table');
    ok(! -e $DBD_PO_Test_Defaults::FILE_0X, 'table file deleted');
}
