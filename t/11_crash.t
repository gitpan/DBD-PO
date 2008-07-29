#!perl -T

use strict;
use warnings;

use Test::DBD::PO::Defaults;
use Test::More tests => 15;

BEGIN {
    require_ok('DBI');
}

my $dbh;

# build table
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

    my $result = $dbh->do(<<"EO_SQL");
        CREATE TABLE $Test::DBD::PO::Defaults::TABLE_11 (
            msgid  VARCHAR,
            msgstr VARCHAR
        )
EO_SQL
    is($result, '0E0', 'create table');
    ok(-e $Test::DBD::PO::Defaults::FILE_11, 'table file found');
}

# write a line and not the header at first
eval {
    $dbh->do(<<"EO_SQL", undef, 'id');
        INSERT INTO $Test::DBD::PO::Defaults::TABLE_11 (
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
        INSERT INTO $Test::DBD::PO::Defaults::TABLE_11 (
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
        INSERT INTO $Test::DBD::PO::Defaults::TABLE_11 (
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
        INSERT INTO $Test::DBD::PO::Defaults::TABLE_11 (
            msgstr
        ) VALUES (?)
EO_SQL
    is($result, 1, 'write a true header');
}

# write a true line
{
    my $result = $dbh->do(<<"EO_SQL", undef, 'id', 'str');
        INSERT INTO $Test::DBD::PO::Defaults::TABLE_11 (
            msgid,
            msgstr
        ) VALUES (?, ?)
EO_SQL
    is($result, 1, 'write a true line');
}

# a line looks like a header
eval {
    $dbh->do(<<"EO_SQL", undef, 'translation');
        INSERT INTO $Test::DBD::PO::Defaults::TABLE_11 (
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
        UPDATE $Test::DBD::PO::Defaults::TABLE_11
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
        UPDATE $Test::DBD::PO::Defaults::TABLE_11
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
        UPDATE $Test::DBD::PO::Defaults::TABLE_11
        SET    msgid=?
        WHERE  msgid=?
EO_SQL
};
like(
    $@,
    qr{\QA line has to have a msgid}xms,
    'change a line to a false line',
);

# drop table
SKIP:
{
    skip('drop table', 2)
        if ! $Test::DBD::PO::Defaults::DROP_TABLE;

    my $result = $dbh->do(<<"EO_SQL");
        DROP TABLE $Test::DBD::PO::Defaults::TABLE_11
EO_SQL
    is($result, '-1', 'drop table');
    ok(! -e $Test::DBD::PO::Defaults::FILE_11, 'table file deleted');
}
