package DBD::PO::dr; # DRIVER

use strict;
use warnings;

use DBD::File;
use parent qw(-norequire DBD::File::dr);
use DBD::PO::Text::PO;

my $PV = 0;
my $IV = 1;
my $NV = 2;

our @PO_TYPES = (
    $IV, # SQL_TINYINT
    $IV, # SQL_BIGINT
    $PV, # SQL_LONGVARBINARY
    $PV, # SQL_VARBINARY
    $PV, # SQL_BINARY
    $PV, # SQL_LONGVARCHAR
    $PV, # SQL_ALL_TYPES
    $PV, # SQL_CHAR
    $NV, # SQL_NUMERIC
    $NV, # SQL_DECIMAL
    $IV, # SQL_INTEGER
    $IV, # SQL_SMALLINT
    $NV, # SQL_FLOAT
    $NV, # SQL_REAL
    $NV, # SQL_DOUBLE
);

our $imp_data_size = 0;
our $data_sources_attr = ();

sub connect ($$;$$$) {
    my ($drh, $dbname, $user, $auth, $attr) = @_;

    my $dbh = $drh->SUPER::connect($dbname, $user, $auth, $attr);
    $dbh->{po_tables} ||= {};
    $dbh->{Active} = 1;

    return $dbh;
}

1;

__END__

=head1 SUBROUTINES/METHOD

=head2 method connect

=cut