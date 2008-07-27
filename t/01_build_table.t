#!perl -T

use strict;
use warnings;

use lib qw(./t/lib);
use DBD_PO_Test_Defaults;

use Test::More tests => 6;
my $module = 'Test::Differences';
eval "use $module";
if ($@) {
    *eq_or_diff = \&is;
    diag("Module $module not installed; $@");
}

BEGIN {
    use_ok('DBI');
}

my $dbh = DBI->connect(
    "dbi:PO:f_dir=$DBD_PO_Test_Defaults::PATH;po_eol=\x0D\x0A;po_separator=\x0A;po_charset=utf-8",
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
    CREATE TABLE $DBD_PO_Test_Defaults::TABLE_0X (
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
ok(-e $DBD_PO_Test_Defaults::TABLE_0X, 'table file found');

my @parameters = (
    join(
        $DBD_PO_Test_Defaults::SEPARATOR,
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
    INSERT INTO $DBD_PO_Test_Defaults::TABLE_0X (
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
    open my $file, '< :raw', $DBD_PO_Test_Defaults::FILE_0X or die $!;
    local $/ = ();
    my $content = <$file>;
    $po =~ s{\n}{$DBD_PO_Test_Defaults::EOL}xmsg;
    eq_or_diff($content, $po, 'check po file');
}