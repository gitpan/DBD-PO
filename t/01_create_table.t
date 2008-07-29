#!perl -T

use strict;
use warnings;

use Test::DBD::PO::Defaults;
use Test::More tests => 6;
eval {
    use Test::Differences;
};
if ($@) {
    *eq_or_diff = \&is;
    diag("Module Test::Differences not installed; $@");
}

BEGIN {
    require_ok('DBI');
}

my $dbh = DBI->connect(
    'dbi:PO:'
    . "f_dir=$Test::DBD::PO::Defaults::PATH;"
    . "po_eol=$Test::DBD::PO::Defaults::EOL;"
    . "po_separator=$Test::DBD::PO::Defaults::SEPARATOR;"
    . 'charset=utf-8',
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
    CREATE TABLE $Test::DBD::PO::Defaults::TABLE_0X (
        comment    VARCHAR,
        automatic  VARCHAR,
        reference  VARCHAR,
        obsolete   INTEGER,
        fuzzy      INTEGER,
        c_format   INTEGER,
        php_format INTEGER,
        msgid      VARCHAR,
        msgstr     VARCHAR
    )
EO_SQL
is($result, '0E0', 'create table');
ok(-e $Test::DBD::PO::Defaults::TABLE_0X, 'table file found');

my @parameters = (
    join(
        $Test::DBD::PO::Defaults::SEPARATOR,
        qw(
            comment1
            comment2
        ),
    ),
    $dbh->func(
        [
            'Testproject',
            'no POT creation date',
            'no PO revision date',
            [
                'Steffen Winkler',
                'steffenw@cpan.org',
            ],
            [
                'MyTeam',
                'cpan@perl.org',
            ],
            undef,
            undef,
            undef,
            [qw(
                X-Poedit-Language      German
                X-Poedit-Country       GERMANY
                X-Poedit-SourceCharset utf-8
            )],
        ],
        'build_header_msgstr',
    ),
);
$result = $dbh->do(<<"EO_SQL", undef, @parameters);
    INSERT INTO $Test::DBD::PO::Defaults::TABLE_0X (
        comment,
        msgstr
    ) VALUES (?, ?)
EO_SQL
is($result, 1, 'insert header');

# check table file
{
    my $po = <<'EOT';
# comment1
# comment2
msgid ""
msgstr ""
"Project-Id-Version: Testproject\n"
"POT-Creation-Date: no POT creation date\n"
"PO-Revision-Date: no PO revision date\n"
"Last-Translator: Steffen Winkler <steffenw@cpan.org>\n"
"Language-Team: MyTeam <cpan@perl.org>\n"
"MIME-Version: 1.0\n"
"Content-Type: text/plain; charset=utf-8\n"
"Content-Transfer-Encoding: 8bit\n"
"X-Poedit-Language: German\n"
"X-Poedit-Country: GERMANY\n"
"X-Poedit-SourceCharset: utf-8"

EOT
    open my $file, '< :raw', $Test::DBD::PO::Defaults::FILE_0X or die $!;
    local $/ = ();
    my $content = <$file>;
    $po =~ s{\n}{$Test::DBD::PO::Defaults::EOL}xmsg;
    eq_or_diff($content, $po, 'check po file');
}
