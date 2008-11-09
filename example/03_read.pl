#!perl

use strict;
use warnings;

use Carp qw(croak);
use DBI ();
use Data::Dumper ();

# for test examples only
our $PATH;
our $TABLE_2X;
eval 'use Test::DBD::PO::Defaults qw($PATH $TABLE_2X)';

my $path  = $PATH
            || q{.};
my $table = $TABLE_2X
            || 'table_xx.po'; # for langueage xx

my $dbh;
# Read the charset from the po file
# and than change the encoding to this charset.
# This is the way to read unicode chars from unknown po files.
my $po_charset = q{};
for (1 .. 2) {
    $dbh = DBI->connect(
        "DBI:PO:f_dir=$path;po_charset=$po_charset",
        undef,
        undef,
        {
            RaiseError => 1,
            PrintError => 0,
        },
    ) or croak 'Cannot connect: ' . DBI->errstr();
    $po_charset = $dbh->func(
        {table => $table},        # wich table
        'charset',                # what to get
        'get_header_msgstr_data', # function name
    );
}

# header msgid is always empty but not NULL
{
    my ($header_msgstr) = $dbh->selectrow_array(<<"EOT");
        SELECT msgstr
        FROM   $table
        WHERE  msgid = ''
EOT

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
    my $sth = $dbh->prepare(<<"EOT");
        SELECT msgid, msgstr
        FROM   $table
        WHERE  msgid <> ''
EOT

    $sth->execute();

    while (my $row = $sth->fetchrow_hashref()) {
        print Data::Dumper->new([$row], [qw(row)])
                          ->Quotekeys(0)
                          ->Useqq(1)
                          ->Dump();
    }
}

$dbh->disconnect();