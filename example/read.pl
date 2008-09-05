#!perl

use strict;
use warnings;

use Carp qw(croak);
use DBI ();
use Data::Dumper ();

my $dbh = DBI->connect(
    'DBI:PO:po_charset=utf-8',
    undef,
    undef,
    {
        RaiseError => 1,
        PrintError => 0,
    },
) or croak 'Cannot connect: ' . DBI->errstr();

# header msgid is always empty but not NULL
{
    my $sth = $dbh->prepare(<<'EOT');
        SELECT msgstr
        FROM   table.po
        WHERE  msgid = ''
EOT

    $sth->execute();

    my $header_msgstr = $sth->fetchrow_array();

    $sth->finish();

    my $header_struct = $dbh->func(
        $header_msgstr,
        'split_header_msgstr', # function name
    );

    print Data::Dumper->new([$header_struct], [qw(header_struct)])
                      ->Quotekeys(0)
                      ->Useqq(1)
                      ->Dump();
}

# row msgid is never empty
{
    my $sth = $dbh->prepare(<<'EOT');
        SELECT msgid, msgstr
        FROM   table.po
        WHERE  msgid <> ''
EOT

    $sth->execute();

    while (my $row = $sth->fetchrow_hashref()) {
        printf "original:\n%s\ntranslation:\n%s\n",
               $row->{msgid},
               $row->{msgstr};
    }
}

$dbh->disconnect();
