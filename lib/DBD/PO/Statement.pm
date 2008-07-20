package DBD::PO::Statement;

use strict;
use warnings;

use DBD::File;
use parent qw(-norequire DBD::File::Statement);

use DBD::PO::Text::PO;
use Socket qw($CRLF);

sub open_table {
    my($self, $data, $table, $createMode, $lockMode) = @_;

    my $dbh = $data->{Database};
    my $tables = $dbh->{po_tables};
    if (! exists $tables->{$table}) {
        $tables->{$table} = {};
    }
    my $meta = $tables->{$table} || {};
    my $po = $meta->{po} || $dbh->{po_po};
    if (! $po) {
        my $class = $meta->{class}
                    || $dbh->{'po_class'}
                    || 'DBD::PO::Text::PO';
        my %opts = (
            eol       => $meta->{'eol'}
                         || $dbh->{'po_eol'}
                         || $CRLF,
            separator => exists $meta->{separator}
                         ? $meta->{separator}
                         : exists $dbh->{po_separator}
                           ? $dbh->{po_separator}
                           : $CRLF,
        );
        $po = $meta->{po}
            = $class->new(\%opts);
    }
    my $file = $meta->{file}
               || $table;
    my $tbl = $self->SUPER::open_table($data, $file, $createMode, $lockMode);
    if ($tbl) {
        $tbl->{po_po} = $po;
        my $types = $meta->{types};
        if ($types) {
           # The 'types' array contains DBI types, but we need types
           # suitable for DBD::Text::PO.
           my $t = [];
           for (@{$types}) {
               if ($_) {
                   $_ = $DBD::PO::PO_TYPES[$_ + 6]
                        || $DBD::PO::PV;
               }
               else {
                   $_ = $DBD::PO::PV;
               }
               push @{$t}, $_;
           }
           $tbl->{types} = $t;
        }
        if (
           ! $createMode
           && ! $self->{ignore_missing_table}
           && $self->command() ne 'DROP'
        ) {
            my ($array, $skipRows);
            if (exists $meta->{skip_rows}) {
                $skipRows = $meta->{skip_rows};
            }
            else {
                $skipRows = exists $meta->{col_names} ? 0 : 1;
            }
            if ($skipRows--) {
#                if (! ($array = $tbl->fetch_row($data))) {
                if (! ($array = \@DBD::PO::dr::COL_NAMES)) {
                    die "Missing header";
                }
                $tbl->{col_names} = $array;
                while ($skipRows--) {
                    $tbl->fetch_row($data);
                }
            }
            $tbl->{first_row_pos} = $tbl->{fh}->tell();
            if (exists $meta->{col_names}) {
                $array = $tbl->{col_names} = $meta->{col_names};
            }
            elsif (! $tbl->{col_names} || ! @{$tbl->{col_names}}) {
                # No column names given; fetch first row and create default
                # names.
                my $cached_row = $tbl->{cached_row}
                               = $tbl->fetch_row($data);
                $array = $tbl->{col_names};
                for (my $i = 0;  $i < @{$cached_row};  $i++) {
                    push @{$array}, "col$i";
                }
            }
            my $index = 0;
            my $columns = $tbl->{col_nums};
            for my $col (@{$array}) {
                $columns->{$col} = $index++;
            }
        }
    }

    return $tbl;
}

sub command {
    return shift->{command};
}

1;

__END__

=pod

=head1 SUBROUTINES/METHODS

=head2 method open_table

=head2 method command

=cut
