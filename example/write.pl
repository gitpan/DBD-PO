use DBI;

$dbh = DBI->connect(
    'DBI:PO:',
    undef,
    undef,
    { RaiseError => 1 },
) or die 'Cannot connect: ' . $DBI->errstr();

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
    undef,
    # function name
    'build_header_msgstr',
);

$dbh->do(<<'EOT', undef, $header_msgstr);
    INSERT INTO table.po (
        msgstr
    ) VALUES (?)
EOT

my $sth = $dbh->prepare(<<'EOT');
    INSERT INTO table.po (
        msgid,
        msgstr
    ) VALUES (?, ?)
EOT

my @data = (
    {
        original    => "text to translate\n2nd line of text",
        translation => "translation\n2nd line of translation",
    }
)

for my $data (@data) {
    $sth->execute(
        $data->{original},
        $data->{translation},
    );
};

$dbh->disconnect();
