#!perl -T

use strict;
use warnings;

use Test::DBD::PO::Defaults;
use Test::More tests => 4;

BEGIN {
    require_ok('DBI');
}

my $dbh;

# connext
{
    $dbh = DBI->connect(
        "dbi:PO:f_dir=$Test::DBD::PO::Defaults::PATH",
        undef,
        undef,
        {
            RaiseError => 1,
            PrintError => 0,
            AutoCommit => 1,
        },
    );
    isa_ok($dbh, 'DBI::db', 'connect');

    if ($Test::DBD::PO::Defaults::TRACE) {
        open my $file, '>', Test::DBD::PO::Defaults::trace_file_name();
        $dbh->trace(4, $file);
    }
}

# drop table
SKIP:
{
    skip('drop table', 2)
        if ! $Test::DBD::PO::Defaults::DROP_TABLE;

    my $result = $dbh->do(<<"EO_SQL");
        DROP TABLE $Test::DBD::PO::Defaults::TABLE_0X
EO_SQL
    is($result, '-1', 'drop table');
    ok(! -e $Test::DBD::PO::Defaults::FILE_0X, 'table file deleted');
}
