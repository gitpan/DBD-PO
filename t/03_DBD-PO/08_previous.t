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
use Test::More tests => 37 + 1;
use Test::NoWarnings;
use Test::Differences;

BEGIN {
    require_ok('DBI');
    require_ok('DBD::PO'); DBD::PO->init(qw(:plural :previous));
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

# previous
{
    my $sth_update = $dbh->prepare(<<"EO_SQL");
        UPDATE $TABLE_0X
        SET    previous_msgctxt=?,previous_msgid=?,previous_msgid_plural=?
        WHERE  msgid=?
EO_SQL
    isa_ok($sth_update, 'DBI::st', 'prepare update');

    my $sth_select = $dbh->prepare(<<"EO_SQL");
        SELECT previous_msgctxt, previous_msgid, previous_msgid_plural
        FROM   $TABLE_0X
        WHERE  msgid=?
EO_SQL
    isa_ok($sth_select, 'DBI::st', 'prepare select');

    my @data = (
        {
            test     => 'set previous, id_value',
            id       => 'id_value',
            set      => [
                'context_old_value',
                'id_old_value',
                undef,
            ],
            get      => [
                'context_old_value',
                'id_old_value',
                q{},
            ],
            callback => sub { check_file(shift, 1, 0, 0, 0) },
        },
        {
            test     => 'reset previous, id_value',
            id       => 'id_value',
            set      => [],
            get      => [ q{}, q{}, q{} ],
            callback => sub { check_file(shift) },
        },
        {
            test     => 'set previous, id_value1\nid_value2',
            id       => "id_value1${SEPARATOR}id_value2",
            set      => [
                "context_old_value1${SEPARATOR}context_old_value2",
                "id_old_value1${SEPARATOR}id_old_value2",
                undef,
            ],
            get      => [
                "context_old_value1${SEPARATOR}context_old_value2",
                "id_old_value1${SEPARATOR}id_old_value2",
                q{},
            ],
            callback => sub { check_file(shift, 0, 1, 0, 0) },
        },
        {
            test     => 'reset previous, id_value1\nid_vlalue2',
            id       => "id_value1${SEPARATOR}id_value2",
            set      => [],
            get      => [ q{}, q{}, q{} ],
            callback => sub { check_file(shift) },
        },
        {
            test     => 'set previous, id_singular',
            id       => 'id_singular',
            set      => [
                undef,
                undef,
                'plural_old_value',
            ],
            get      => [
                q{},
                q{},
                'plural_old_value',
            ],
            callback => sub { check_file(shift, 0, 0, 1, 0) },
        },
        {
            test     => 'reset previous, id_singular',
            id       => 'id_singular',
            set      => [],
            get      => [ q{}, q{}, q{} ],
            callback => sub { check_file(shift) },
        },
        {
            test     => 'set previous, id_singular1\nid_singular2',
            id       => "id_singular1${SEPARATOR}id_singular2",
            set      => [
                undef,
                undef,
                "plural_old_value1${SEPARATOR}plural_old_value2",
            ],
            get      => [
                q{},
                q{},
                "plural_old_value1${SEPARATOR}plural_old_value2",
            ],
            callback => sub { check_file(shift, 0, 0, 0, 1) },
        },
        {
            test     => 'reset previous, id_singular1\nid_singular2',
            id       => "id_singular1${SEPARATOR}id_singular2",
            set      => [],
            get      => [ q{}, q{}, q{} ],
            callback => sub { check_file(shift) },
        },
    );
    for my $data (@data) {
        my $result = $sth_update->execute(
            @{ $data->{set} }[0 .. 2],
            $data->{id},
        );
        is($result, 1, "update: $data->{test}");

        $result = $sth_select->execute(
            $data->{id},
        );
        is($result, 1, "select: $data->{test}");
        $result = $sth_select->fetchrow_arrayref();
        is_deeply($result, $data->{get}, "fetch result: $data->{test}");

        $data->{callback}->( $data->{test} );
    }
}

# check table file
sub check_file {
    my ($test, @previous) = @_;

    my $po = <<'EOT';
# comment1
# comment2
msgid ""
msgstr ""
"Project-Id-Version: Testproject\n"
"Report-Msgid-Bugs-To: Bug Reporter <bug@example.org>\n"
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
EOT
    $po .= <<'EOT' if $previous[0];
#| msgctxt "context_old_value"
#| msgid "id_old_value"
EOT
    $po .= <<'EOT';
msgctxt "context_value"
msgid "id_value"
msgstr "str_value"

# comment_value1
# comment_value2
#. automatic_value1
#. automatic_value2
#: ref_value1
#: ref_value2
EOT
    $po .= <<'EOT' if $previous[1];
#| msgctxt ""
"context_old_value1\n"
"context_old_value2"
#| msgid ""
"id_old_value1\n"
"id_old_value2"
EOT
    $po .= <<'EOT';
msgctxt ""
"context_value1\n"
"context_value2"
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
    $po .= <<'EOT' if $previous[2];
#| msgid_plural "plural_old_value"
EOT
    $po .= <<'EOT';
msgid "id_singular"
msgid_plural "id_plural"
msgstr[0] "str_singular"
msgstr[1] "str_plural"

EOT
    $po .= <<'EOT' if $previous[3];
#| msgid_plural ""
"plural_old_value1\n"
"plural_old_value2"
EOT
    $po .= <<'EOT';
msgid ""
"id_singular1\n"
"id_singular2"
msgid_plural ""
"id_plural1\n"
"id_plural2"
msgstr[0] ""
"str_singular1\n"
"str_singular2"
msgstr[1] ""
"str_plural1\n"
"str_plural2"

msgid "id_value_singular_mini"
msgid_plural "id_value_plural_mini"
msgstr[0] ""

EOT
    open my $file, '< :raw', $FILE_0X or croak $OS_ERROR;
    local $INPUT_RECORD_SEPARATOR = ();
    my $content = <$file>;
    $po =~ s{\n}{$EOL}xmsg;
    eq_or_diff($content, $po, 'check po file');
}