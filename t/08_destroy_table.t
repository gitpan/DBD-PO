#!perl -T

use strict;
use warnings;

#use Carp qw(confess); $SIG{__DIE__} = \&confess;
use Test::More tests => 4;

BEGIN {
    use_ok('DBI');
}

my $table = 'po_test.po';
my $dbh;

# connext
{
    $dbh = DBI->connect(
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
        open my $file, '>', 'trace_07.txt';
        $dbh->trace(4, $file);
    }
}

# destroy table
{
    my $result = $dbh->do(<<"EO_SQL");
        DROP TABLE $table
EO_SQL
    is($result, '-1', 'drop table');
    ok(! -e $table, 'table file deleted');
}