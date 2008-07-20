#!perl -T

use strict;
use warnings;

#use Carp qw(confess); $SIG{__DIE__} = \&confess;
use Socket qw($CRLF);

use Test::More tests => 10;
my $module = 'Test::Differences';
eval "use $module";
if ($@) {
    *eq_or_diff = \&is;
}

BEGIN {
    use_ok('DBI');
}

my $table = 'po_test.po';
my ($dbh, $sth);
my $separator = $CRLF;

# connext
{
    $dbh = DBI->connect(
        "dbi:PO:separator=$CRLF",
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
        open my $file, '>', 'trace_02.txt';
        $dbh->trace(4, $file);
    }
}

# full row
{
    $sth = $dbh->prepare(<<"EO_SQL");
        INSERT INTO $table (
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
        "id_value1${separator}id_value2",
        "str_value1${separator}str_value2",
        "ref_value1${separator}ref_value2",
        "comment_value1${separator}comment_value2",
        "automatic_value1${separator}automatic_value2",
    );
    is($result, 1, "insert full row, all are arrays");
}

# minimized row
{
    my $result = $dbh->do(<<"EO_SQL", undef, 'id_value_mini');
        INSERT INTO $table (msgid) VALUES (?)
EO_SQL
    is($result, 1, "insert minimized row");
}

# typical rows
{
    $sth = $dbh->prepare(<<"EO_SQL");
        INSERT INTO $table (msgid, msgstr) VALUES (?, ?)
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
    open my $file, '<:raw', $table or die $!;
    local $/ = ();
    my $content = <$file>;
    $po =~ s{\n}{$CRLF}xmsg;
    eq_or_diff($content, $po, 'check po file');
}