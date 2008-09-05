#!perl

use strict;
use warnings;

use Carp qw(croak);
use DBI ();

my $dbh = DBI->connect(
    'DBI:PO:po_charset=utf-8',
    undef,
    undef,
    {
        RaiseError => 1,
        PrintError => 0,
    },
) or croak 'Cannot connect: ' . DBI->errstr();

$dbh->do(<<'EOT');
    CREATE TABLE
        table.po (
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
$dbh->do(<<'EOT', undef, $header_msgstr);
    INSERT INTO table.po (
        msgstr
    ) VALUES (?)
EOT

# row msgid must have a length
# row msgstr can be empty (NULL or q{}), will get back as q{}
my $sth = $dbh->prepare(<<'EOT');
    INSERT INTO table.po (
        msgid,
        msgstr
    ) VALUES (?, ?)
EOT

my @data = (
    {
        original    => 'text to translate',
        translation => 'translation',
    },
    {
        original    => "text2 to translate\n2nd line of text2",
        translation => "translation2\n2nd line of translation2",
    },
);

for my $data (@data) {
    $sth->execute(
        $data->{original},    # msgid
        $data->{translation}, # msgstr
    );
};

$dbh->disconnect();