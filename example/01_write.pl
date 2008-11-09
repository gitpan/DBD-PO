#!perl

use strict;
use warnings;

use Carp qw(croak);
use DBI ();

# for test examples only
our $PATH;
our $TABLE_2X;
eval 'use Test::DBD::PO::Defaults qw($PATH $TABLE_2X)';

my $path  = $PATH
            || q{.};
my $table = $TABLE_2X
            || 'table_xx.po'; # for langueage xx

my $dbh = DBI->connect(
    "DBI:PO:f_dir=$path;po_charset=utf-8",
    undef,
    undef,
    {
        RaiseError => 1,
        PrintError => 0,
    },
) or croak 'Cannot connect: ' . DBI->errstr();

$dbh->do(<<"EOT");
    CREATE TABLE
        $table (
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
EOT

my $header_msgstr = $dbh->func(
    undef, # minimized
    'build_header_msgstr', # function name
);

# header msgid is always empty, will set to NULL or q{} and get back as q{}
# header msgstr must have a length
$dbh->do(<<"EOT", undef, $header_msgstr);
    INSERT INTO $table (
        msgstr
    ) VALUES (?)
EOT

# row msgid must have a length
# row msgstr can be empty (NULL or q{}), will get back as q{}
my $sth = $dbh->prepare(<<"EOT");
    INSERT INTO $table (
        msgid,
        msgstr
    ) VALUES (?, ?)
EOT

my @data = (
    {
        original    => 'text1 original',
        translation => 'text1 translated',
    },
    {
        original    => "text2 original\n2nd line of text2",
        translation => "text2 translated\n2nd line of text2",
    },
    {
        original    => 'text3 original %1',
        translation => 'text3 translated %1',
    },
    {
        original    => 'text4 original [quant,_1,o_one,o_more,o_nothing]',
        translation => 'text4 translated [quant,_1,t_one,t_more,t_nothing]',
    },
);

for my $data (@data) {
    $sth->execute(
        $dbh->func(
            @{$data}{qw(original translation)}, # msgid + msgstr
            'maketext_to_gettext',
        ),
    );
};

$dbh->disconnect();