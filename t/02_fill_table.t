#!perl -T

use strict;
use warnings;

use Test::DBD::PO::Defaults;
use Test::More tests => 10;
eval {
    use Test::Differences;
};
if ($@) {
    *eq_or_diff = \&is;
    diag('Module Test::Differences not installed');
}

BEGIN {
    require_ok('DBI');
}

my ($dbh, $sth);

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

# full row
{
    $sth = $dbh->prepare(<<"EO_SQL");
        INSERT INTO $Test::DBD::PO::Defaults::TABLE_0X (
            msgid,
            msgstr,
            reference,
            comment,
            automatic
        ) VALUES (?, ?, ?, ?, ?)
EO_SQL
    isa_ok($sth, 'DBI::st', 'prepare insert');

    my $result = $sth->execute(qw(
        id_value
        str_value
        ref_value
        comment_value
        automatic_value
    ));
    is($result, 1, "insert full row");
}

# full row, all are arrays
{
    my $result = $sth->execute(
        "id_value1${Test::DBD::PO::Defaults::SEPARATOR}id_value2",
        "str_value1${Test::DBD::PO::Defaults::SEPARATOR}str_value2",
        "ref_value1${Test::DBD::PO::Defaults::SEPARATOR}ref_value2",
        "comment_value1${Test::DBD::PO::Defaults::SEPARATOR}comment_value2",
        "automatic_value1${Test::DBD::PO::Defaults::SEPARATOR}automatic_value2",
    );
    is($result, 1, "insert full row, all are arrays");
}

# minimized row
{
    my $result = $dbh->do(<<"EO_SQL", undef, 'id_value_mini');
        INSERT INTO $Test::DBD::PO::Defaults::TABLE_0X (msgid) VALUES (?)
EO_SQL
    is($result, 1, "insert minimized row");
}

# typical rows
{
    $sth = $dbh->prepare(<<"EO_SQL");
        INSERT INTO $Test::DBD::PO::Defaults::TABLE_0X (msgid, msgstr) VALUES (?, ?)
EO_SQL
    isa_ok($sth, 'DBI::st', 'prepare insert');

    for (1 .. 2) {
        my $result = $sth->execute("id_$_", "str_$_");
        is($result, 1, "insert row $_");
    }
}

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

# comment_value
#. automatic_value
#: ref_value
msgid "id_value"
msgstr "str_value"

# comment_value1
# comment_value2
#. automatic_value1
#. automatic_value2
#: ref_value1
#: ref_value2
msgid ""
"id_value1\n"
"id_value2"
msgstr ""
"str_value1\n"
"str_value2"

msgid "id_value_mini"
msgstr ""

msgid "id_1"
msgstr "str_1"

msgid "id_2"
msgstr "str_2"

EOT
    open my $file, '< :raw', $Test::DBD::PO::Defaults::FILE_0X or die $!;
    local $/ = ();
    my $content = <$file>;
    $po =~ s{\n}{$Test::DBD::PO::Defaults::EOL}xmsg;
    eq_or_diff($content, $po, 'check po file');
}
