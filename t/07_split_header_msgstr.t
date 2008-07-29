#!perl -T

use strict;
use warnings;

use Test::DBD::PO::Defaults;
use Test::More tests => 5;

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

my $sth = $dbh->prepare(<<"EO_SQL");
        SELECT msgstr
        FROM   $Test::DBD::PO::Defaults::TABLE_0X
        WHERE  msgid=''
EO_SQL
isa_ok($sth, 'DBI::st', 'prepare');

is(
    $sth->execute(),
    1,
    'execute',
);

my ($msgstr) = $sth->fetchrow_array();
is_deeply(
    $dbh->func($msgstr, 'split_header_msgstr'),
    [
        'Testproject',
        'no POT creation date',
        'no PO revision date',
        [
            'Steffen Winkler',
            'steffenw@cpan.org'
        ],
        [
            'MyTeam',
            'cpan@perl.org',
        ],
        '1.0',
        [
            'text/plain',
            'utf-8',
        ],
        '8bit',
        [qw(
            X-Poedit-Language      German
            X-Poedit-Country       GERMANY
            X-Poedit-SourceCharset utf-8
        )],
    ],
    'split header msgstr',
);
