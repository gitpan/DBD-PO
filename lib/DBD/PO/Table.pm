package DBD::PO::Table;

use strict;
use warnings;

use DBD::File;
use parent qw(-norequire DBD::File::Table);

sub fetch_row ($$) {
    my ($self, $data) = @_;

    my $fields;
    if (exists $self->{cached_row}) {
        $fields = delete $self->{cached_row};
    }
    else {
        $! = 0;
        my $po = $self->{po_po};
        local $/ = $po->{'eol'};
        $fields = $po->getline($self->{'fh'});
        if (! $fields) {
           die "Error while reading file $self->{file}: $!" if $!;
           return;
        }
    }

    return $self->{row} = @{$fields} ? $fields : ();
}

sub push_row ($$$) {
    my ($self, $data, $fields) = @_;

    my $po = $self->{po_po};
    my $fh = $self->{fh};
    #
    #  Remove undef from the right end of the fields, so that at least
    #  in these cases undef is returned from FetchRow
    #
    while (@{$fields} && ! defined $fields->[$#{$fields}]) {
        pop @{$fields};
    }
    if (! $po->print($fh, $fields)) {
        die "Error while writing file $self->{file}: $!";
    }

    return 1;
}

#*push_names = \&push_row;
sub push_names ($$$) {
    my ($self, $data, $fields) = @_;

    return 1;
}

1;

__END__

=head1 SUBROUTINES/METHODS

=head2 method fetch_row

=head2 method push_row

=head2 method push_names

=cut
