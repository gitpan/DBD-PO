#!perl -T

use strict;
use warnings;

use Carp qw(croak);
use English qw(-no_match_vars $OS_ERROR $INPUT_RECORD_SEPARATOR);
use Test::DBD::PO::Defaults qw(
    $PATH $TRACE $SEPARATOR $EOL
    trace_file_name
    $TABLE_0X $FILE_0X
);
use Test::More tests => 12 + 1;
use Test::NoWarnings;
use Test::Differences;

BEGIN {
    require_ok('DBI');
}

my $dbh;

# connext
{
    $dbh = DBI->connect(
        "dbi:PO:f_dir=$PATH;po_charset=utf-8",
        undef,
        undef,
        {
            RaiseError => 1,
            PrintError => 0,
            AutoCommit => 1,
        },
    );
    isa_ok($dbh, 'DBI::db', 'connect');

    if ($TRACE) {
        open my $file, '>', trace_file_name();
        $dbh->trace(4, $file);
    }
}

# obsolete
{
    my $sth_update = $dbh->prepare(<<"EO_SQL");
        UPDATE $TABLE_0X
        SET    obsolete=?
        WHERE  msgid=?
EO_SQL
    isa_ok($sth_update, 'DBI::st', 'prepare update');

    my $sth_select = $dbh->prepare(<<"EO_SQL");
        SELECT obsolete
        FROM   $TABLE_0X
        WHERE  msgid=?
EO_SQL
    isa_ok($sth_select, 'DBI::st', 'prepare select');

    my @data = (
        {
            test     => 'obsolete=1',
            set      => 1,
            result   => 1,
            get      => [1],
            callback => sub { check_file(shift, 1) },
        },
        {
            test     => 'obsolete=0',
            set      => 0,
            result   => 1,
            get      => [0],
            callback => sub { check_file(shift) },
        },
    );
    for my $data (@data) {
        my $result = $sth_update->execute(
            $data->{set},
            "id_value1${SEPARATOR}id_value2",
        );
        is($result, $data->{result}, "update: $data->{test}");

        $result = $sth_select->execute(
            "id_value1${SEPARATOR}id_value2",
        );
        is($result, 1, "select: $data->{test}");
        $result = $sth_select->fetchrow_arrayref();
        is_deeply($result, $data->{get}, "fetch result: $data->{test}");

        $data->{callback}->( $data->{test} );
    }
}

# check table file
sub check_file {
    my ($test, $obsolete) = @_;

    my $po = <<'EOT';
# comment1
# comment2
msgid ""
msgstr ""
"Project-Id-Version: Testproject\n"
"POT-Creation-Date: no POT creation date\n"
"PO-Revision-Date: no PO revision date\n"
"Last-Translator: Steffen Winkler <steffenw@example.org>\n"
"Language-Team: MyTeam <cpan@example.org>\n"
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
EOT
    $po .= <<'EOT' if ! $obsolete;
msgid ""
"id_value1\n"
"id_value2"
msgstr ""
"str_value1\n"
"str_value2"

EOT
    $po .= <<'EOT' if $obsolete;
#~ msgid ""
"id_value1\n"
"id_value2"
#~ msgstr ""
"str_value1\n"
"str_value2"

EOT
    $po .= <<'EOT';
msgid "id_value_mini"
msgstr ""

msgid "id_1"
msgstr "str_1u"

msgid "id_2"
msgstr "str_2"

EOT
    open my $file, '< :raw', $FILE_0X or croak $OS_ERROR;
    local $INPUT_RECORD_SEPARATOR = ();
    my $content = <$file>;
    $po =~ s{\n}{$EOL}xmsg;
    eq_or_diff($content, $po, 'check po file');
}
