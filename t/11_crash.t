#!perl -T

use strict;
use warnings;

use lib qw(./t/lib);
use DBD_PO_Test_Defaults;

use Test::More tests => 15;

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
        CREATE TABLE $DBD_PO_Test_Defaults::TABLE_11 (
            msgid  VARCHAR,
            msgstr VARCHAR
        )
EO_SQL
    is($result, '0E0', 'create table');
    ok(-e $DBD_PO_Test_Defaults::FILE_11, 'table file found');
}

# write a line and not the header at first
eval {
    $dbh->do(<<"EO_SQL", undef, 'id');
        INSERT INTO $DBD_PO_Test_Defaults::TABLE_11 (
            msgid
        ) VALUES (?)
EO_SQL
};
like(
    $@,
    qr{\QA header has no msgid}xms,
    'write a line and not the header at first',
);

# write an empty header
eval {
    $dbh->do(<<"EO_SQL", undef, undef);
        INSERT INTO $DBD_PO_Test_Defaults::TABLE_11 (
            msgstr
        ) VALUES (?)
EO_SQL
};
like(
    $@,
    qr{\QA header has to have a msgstr}xms,
    'write an empty header',
);

# write a false header
eval {
    $dbh->do(<<"EO_SQL", undef, 'false');
        INSERT INTO $DBD_PO_Test_Defaults::TABLE_11 (
            msgstr
        ) VALUES (?)
EO_SQL
};
like(
    $@,
    qr{\QThis can not be a header}xms,
    'write a false header',
);

# write a true header
{
    my $msgstr = $dbh->func(undef, 'build_header_msgstr');
    my $result = $dbh->do(<<"EO_SQL", undef, $msgstr);
        INSERT INTO $DBD_PO_Test_Defaults::TABLE_11 (
            msgstr
        ) VALUES (?)
EO_SQL
    is($result, 1, 'write a true header');
}

# write a true line
{
    my $result = $dbh->do(<<"EO_SQL", undef, 'id', 'str');
        INSERT INTO $DBD_PO_Test_Defaults::TABLE_11 (
            msgid,
            msgstr
        ) VALUES (?, ?)
EO_SQL
    is($result, 1, 'write a true line');
}

# a line looks like a header
eval {
    $dbh->do(<<"EO_SQL", undef, 'translation');
        INSERT INTO $DBD_PO_Test_Defaults::TABLE_11 (
            msgstr
        ) VALUES (?)
EO_SQL
};
like(
    $@,
    qr{\Q A line has to have a msgid}xms,
    'a line looks like a header',
);

# change a header to an empty header
eval {
    $dbh->do(<<"EO_SQL", undef, q{}, q{});
        UPDATE $DBD_PO_Test_Defaults::TABLE_11
        SET    msgstr=?
        WHERE  msgid=?
EO_SQL
};
like(
    $@,
    qr{\QA header has to have a msgstr}xms,
    'change a header to an empty header',
);

# change a header to a false header
eval {
    $dbh->do(<<"EO_SQL", undef, 'false', q{});
        UPDATE $DBD_PO_Test_Defaults::TABLE_11
        SET    msgstr=?
        WHERE  msgid=?
EO_SQL
};
like(
    $@,
    qr{\QThis can not be a header}xms,
    'change a header to a false header',
);

# change a line to a false line
eval {
    $dbh->do(<<"EO_SQL", undef, q{}, 'id');
        UPDATE $DBD_PO_Test_Defaults::TABLE_11
        SET    msgid=?
        WHERE  msgid=?
EO_SQL
};
like(
    $@,
    qr{\QA line has to have a msgid}xms,
    'change a line to a false line',
);

# destroy table
{
    my $result = $dbh->do(<<"EO_SQL");
        DROP TABLE $DBD_PO_Test_Defaults::TABLE_11
EO_SQL
    is($result, '-1', 'drop table');
    ok(! -e $DBD_PO_Test_Defaults::FILE_11, 'table file deleted');
}