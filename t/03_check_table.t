#!perl -T

use strict;
use warnings;

use lib qw(./t/lib);
use DBD_PO_Test_Defaults;

use Test::More tests => 8;
my $module = 'Test::Differences';
eval "use $module";
if ($@) {
    *eq_or_diff = \&is;
    diag("Module $module not installed; $@");
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

# check table
{
    my $sth = $dbh->prepare(<<"EO_SQL");
        SELECT msgid, msgstr
        FROM   $DBD_PO_Test_Defaults::TABLE_0X
        WHERE  msgid=?
EO_SQL
    isa_ok($sth, 'DBI::st');

    my @data = (
        {
            id     => 'id_2',
            _id    => 'id_2',
            result => 1,
            fetch  => [
                {
                    msgid  => 'id_2',
                    msgstr => 'str_2',
                },
            ],
        },
        {
            id     => "id_value1${DBD_PO_Test_Defaults::SEPARATOR}id_value2",
            _id    => "id_value1\${separator}id_value2",
            result => 1,
            fetch  => [
                {
                    msgid  => "id_value1${DBD_PO_Test_Defaults::SEPARATOR}id_value2",
                    msgstr => "str_value1${DBD_PO_Test_Defaults::SEPARATOR}str_value2",
                },
            ],
        },
    );

    for my $data (@data) {
        my $result = $sth->execute($data->{id});
        is($result, $data->{result}, "execute: $data->{_id}");

        $result = $sth->fetchall_arrayref( {} );
        is_deeply(
            $result,
            $data->{fetch},
            "fetch result: $data->{_id}",
        );
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
    open my $file, '< :raw', $DBD_PO_Test_Defaults::FILE_0X or die $!;
    local $/ = ();
    my $content = <$file>;
    $po =~ s{\n}{$DBD_PO_Test_Defaults::EOL}xmsg;
    eq_or_diff($content, $po, 'check po file');
}