#!perl -T

use strict;
use warnings;

#use Carp qw(confess); $SIG{__DIE__} = \&confess;
use Socket qw($CRLF);

use Test::More tests => 6;
my $module = 'Test::Differences';
eval "use $module";
if ($@) {
    *eq_or_diff = \&is;
}

BEGIN {
    use_ok('DBI');
}

my $table     = 'po_test.po';
my $separator = $CRLF;

my $dbh = DBI->connect(
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
    open my $file, '>', 'trace_01.txt';
    $dbh->trace(4, $file);
}

my $result = $dbh->do(<<"EO_SQL");
    CREATE TABLE $table (
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
ok(-e $table, 'table file found');

my @parameters = (
    join(
        $separator,
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
    INSERT INTO $table (
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
    open my $file, '<:raw', $table or die $!;
    local $/ = ();
    my $content = <$file>;
    $po =~ s{\n}{$CRLF}xmsg;
    eq_or_diff($content, $po, 'check po file');
}