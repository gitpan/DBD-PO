#!perl -T

use strict;
use warnings;

#use Carp qw(confess); $SIG{__DIE__} = \&confess;
use Socket qw($CRLF);

use Test::More tests => 7;
my $module = 'Test::Differences';
eval "use $module";
if ($@) {
    *eq_or_diff = \&is;
}

BEGIN {
    use_ok('DBI');
}

my $table = 'po_test.po';
my $dbh;
my $separator = $CRLF;

# connext
{
    $dbh = DBI->connect(
        'dbi:PO:',
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
        open my $file, '>', 'trace_04.txt';
        $dbh->trace(4, $file);
    }
}

# change table
{
    my $result = $dbh->do(<<"EO_SQL", undef, qw(str_1u id_1));
        UPDATE $table
        SET    msgstr=?
        WHERE  msgid=?
EO_SQL
    is($result, 1, 'update row 1');

    my $sth = $dbh->prepare(<<"EO_SQL");
        SELECT msgid, msgstr
        FROM   $table
        WHERE  msgid=?
EO_SQL
    isa_ok($sth, 'DBI::st', 'prepare');

    $result = $sth->execute('id_1');
    is($result, 1, 'execute');

    $result = $sth->fetchrow_arrayref();
    is_deeply($result, [qw(id_1 str_1u)], 'fetch result');
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
msgstr "str_1u"

msgid "id_2"
msgstr "str_2"

EOT
    open my $file, '<:raw', $table or die $!;
    local $/ = ();
    my $content = <$file>;
    $po =~ s{\n}{$CRLF}xmsg;
    eq_or_diff($content, $po, 'check po file');
}