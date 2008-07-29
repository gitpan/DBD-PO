#!perl -T

use strict;
use warnings;

use Test::DBD::PO::Defaults;
use Test::More tests => 42;
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

# change header flags
{
    my $sth_update = $dbh->prepare(<<"EO_SQL");
        UPDATE $Test::DBD::PO::Defaults::TABLE_0X
        SET    fuzzy=?
        WHERE  msgid=?
EO_SQL
    isa_ok($sth_update, 'DBI::st', 'prepare update header');

    my $sth_select = $dbh->prepare(<<"EO_SQL");
        SELECT fuzzy
        FROM   $Test::DBD::PO::Defaults::TABLE_0X
        WHERE  msgid=?
EO_SQL
    isa_ok($sth_select, 'DBI::st', 'prepare select header');

    my @data = (
        {
            test     => 'header fuzzy=1',
            set      => 1,
            get      => [1],
            callback => sub { check_file(shift, 'header_fuzzy') },
        },
        {
            test     => 'header fuzzy=0',
            set      => 0,
            get      => [0],
            callback => sub { check_file(shift) },
        },
    );
    for my $data (@data) {
        my $result = $sth_update->execute($data->{set}, q{});
        is($result, 1, "update: $data->{test}");

        $result = $sth_select->execute(q{});
        is($result, 1, "select: $data->{test}");
        $result = $sth_select->fetchrow_arrayref();
        is_deeply($result, $data->{get}, "fetch result: $data->{test}");

        $data->{callback}->( $data->{test} );
    }
}

# change flags
{
    my $sth_update = $dbh->prepare(<<"EO_SQL");
        UPDATE $Test::DBD::PO::Defaults::TABLE_0X
        SET    fuzzy=?, c_format=?, php_format=?
        WHERE  msgid=?
EO_SQL
    isa_ok($sth_update, 'DBI::st');

    my $sth_select = $dbh->prepare(<<"EO_SQL");
        SELECT fuzzy, c_format, php_format
        FROM   $Test::DBD::PO::Defaults::TABLE_0X
        WHERE  msgid=?
EO_SQL
    isa_ok($sth_select, 'DBI::st');

    my @data = (
        {
            test     => 'fuzzy=1',
            set      => [1, 0, 0],
            get      => [
                {
                    fuzzy      => 1,
                    c_format   => 0,
                    php_format => 0,
                }
            ],
            callback => sub { check_file(shift, 'fuzzy') },
        },
        {
            test     => 'c-format=1',
            set      => [0, 1, 0],
            get      => [
                {
                    fuzzy      => 0,
                    c_format   => 1,
                    php_format => 0,
                },
            ],
            callback => sub { check_file(shift, 'c-format') },
        },
        {
            test     => 'php-format=1',
            set      => [0, 0, 1],
            get      => [
                {
                    fuzzy      => 0,
                    c_format   => 0,
                    php_format => 1,
                },
            ],
            callback => sub { check_file(shift, 'php-format') },
        },
        {
            test     => 'c-format=-1',
            set      => [0, -1, 0],
            get      => [
                {
                    fuzzy      => 0,
                    c_format   => -1,
                    php_format => 0,
                }
            ],
            callback => sub { check_file(shift, 'no-c-format') },
        },
        {
            test     => 'php-format=-1',
            set      => [0, 0, -1],
            get      => [
                {
                    fuzzy      => 0,
                    c_format   => 0,
                    php_format => -1,
                }
            ],
            callback => sub { check_file(shift, 'no-php-format') },
        },
        {
            test     => 'all=1',
            set      => [(1) x 3],
            get      => [
                {
                    fuzzy      => 1,
                    c_format   => 1,
                    php_format => 1,
                }
            ],
            callback => sub { check_file(shift, 'all') },
        },
        {
            test     => 'all=0',
            set      => [(0) x 3],
            result   => 1,
            get      => [
                {
                    fuzzy      => 0,
                    c_format   => 0,
                    php_format => 0,
                }
            ],
            callback => sub { check_file(shift) },
        },
    );
    for my $data (@data) {
        my $result = $sth_update->execute(
            @{ $data->{set} },
            "id_value1${Test::DBD::PO::Defaults::SEPARATOR}id_value2",
        );
        is($result, 1, "update: $data->{test}");

        $result = $sth_select->execute("id_value1${Test::DBD::PO::Defaults::SEPARATOR}id_value2");
        is($result, 1, "select: $data->{test}");
        $result = $sth_select->fetchall_arrayref({});
        is_deeply($result, $data->{get}, "fetch result: $data->{test}");

        $data->{callback}->( $data->{test} );
    }
}

# check table file
sub check_file {
    my $test = shift;
    my $flag = shift || q{};

    my $po = <<'EOT';
# comment1
# comment2
EOT
    $po .= <<'EOT' if $flag eq 'header_fuzzy';
#, fuzzy
EOT
    $po .= <<'EOT';
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
EOT
    $po .= <<'EOT' if $flag eq 'fuzzy';
#, fuzzy
EOT
    $po .= <<'EOT' if $flag eq 'c-format';
#, c-format
EOT
    $po .= <<'EOT' if $flag eq 'no-c-format';
#, no-c-format
EOT
    $po .= <<'EOT' if $flag eq 'php-format';
#, php-format
EOT
    $po .= <<'EOT' if $flag eq 'no-php-format';
#, no-php-format
EOT
    $po .= <<'EOT' if $flag eq 'all';
#, c-format, fuzzy, php-format
EOT
    $po .= <<'EOT';
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
    open my $file, '< :raw', $Test::DBD::PO::Defaults::FILE_0X or die $!;
    local $/ = ();
    my $content = <$file>;
    $po =~ s{\n}{$Test::DBD::PO::Defaults::EOL}xmsg;
    eq_or_diff($content, $po, "check po file: $test");

    return;
}
