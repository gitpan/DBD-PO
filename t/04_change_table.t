#!perl -T

use strict;
use warnings;

use lib qw(./t/lib);
use DBD_PO_Test_Defaults;

use Test::More tests => 7;
my $module = 'Test::Differences';
eval "use $module";
if ($@) {
    *eq_or_diff = \&is;
}

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

# change table
{
    my $result = $dbh->do(<<"EO_SQL", undef, qw(str_1u id_1));
        UPDATE $DBD_PO_Test_Defaults::TABLE_0X
        SET    msgstr=?
        WHERE  msgid=?
EO_SQL
    is($result, 1, 'update row 1');

    my $sth = $dbh->prepare(<<"EO_SQL");
        SELECT msgid, msgstr
        FROM   $DBD_PO_Test_Defaults::TABLE_0X
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
    open my $file, '<:raw', $DBD_PO_Test_Defaults::FILE_0X or die $!;
    local $/ = ();
    my $content = <$file>;
    $po =~ s{\n}{$DBD_PO_Test_Defaults::EOL}xmsg;
    eq_or_diff($content, $po, 'check po file');
}
