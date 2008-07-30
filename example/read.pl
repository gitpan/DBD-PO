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

$sth = $dbh->prepare(<<'EOT');
    SELECT msgid, msgstr
    FROM   table.po
    WHERE  msgid = ?
EOT

$sth->execute(q{});

my (undef, $header_msgstr) = $sth->fetchrow_array();
my $header_struct = $dbh->func(
    $header_msgstr,
    # function name
    'split_header_msgstr',
);

while (my $row = $sth->fetchrow_arrarref()) {
    printf "original: %s\ntranslation: %s",
           $row->{msgid},
           $row->{msgstr};
}

$dbh->disconnect();
