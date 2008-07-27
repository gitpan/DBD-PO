package DBD::PO::db; # DATABASE

use strict;
use warnings;

use DBD::File;
use parent qw(-norequire DBD::File::db);

use Carp qw(croak);
use SQL::Statement; # for SQL::Parser
use SQL::Parser;
use DBD::PO::Locale::PO;

our $imp_data_size = 0;

sub build_header_msgstr {
    my ($dbh, $data) = @_;

    my @header;
    HEADER_KEY:
    for my $index (0 .. $#DBD::PO::dr::HEADER_KEYS) {
        my $data = $data->[$index]
                   || $DBD::PO::dr::HEADER_DEFAULTS[$index];
        defined $data
            or next HEADER_KEY;
        my $key    = $DBD::PO::dr::HEADER_KEYS[$index];
        my $format = $DBD::PO::dr::HEADER_FORMATS[$index];
        my @data = defined $data
                   ? (
                       ref $data eq 'ARRAY'
                       ? @{ $data }
                       : $data
                   )
                   : ();
        if ($key eq 'content_type') {
            my $charset = defined $dbh->FETCH('charset')
                          ? $dbh->FETCH('charset')
                          : $DBD::PO::dr::CHARSET_DEFAULT;
            if ($charset) {
                $data[1] = $charset;
            }
        }
        @data
            or next HEADER_KEY;
        if ($key eq 'extended') {
            @data % 2
               and croak "$key pairs are not pairwise";
            while (my ($name, $value) = splice @data, 0, 2) {
                push @header, sprintf $format, $name, $value;
            }
        }
        else {
            push @header, sprintf $format, @data;
        }
    }
    @header or return q{};

    return join "\\n", @header;
}

sub split_header_msgstr {
    my ($dbh, $msgstr) = @_;

    my $po = DBD::PO::Locale::PO->new(
        eol => defined $dbh->FETCH('eol')
               ? $dbh->FETCH('eol')
               : $DBD::PO::dr::EOL_DEFAULT,
    );
    my $separator = defined $dbh->FETCH('separator')
                    ? $dbh->FETCH('separator')
                    : $DBD::PO::dr::SEPARATOR_DEFAULT;
    my @cols;
    my $index = 0;
    my @lines = split m{\Q$separator\E}xms, $msgstr;
    LINE:
    while (1) {
        my $line = shift @lines;
        defined $line
           or last LINE;
        my $index = 0;
        HEADER_REGEX:
        for my $header_regex (@DBD::PO::dr::HEADER_REGEX) {
            if (! $header_regex) {
                ++$index;
                next HEADER_REGEX;
            }
            my @result = $line =~ $header_regex;
            if (@result) {
                defined $cols[$index]
                ? (
                    ref $cols[$index] eq 'ARRAY'
                    ? push @{ $cols[$index] }, @result
                    : do {
                        $cols[$index] = [ $cols[$index], @result ];
                    }
                )
                : (
                    $cols[$index] = @result > 1
                                    ? \@result
                                    : $result[0]
                );
                next LINE;
            }
            ++$index;
        }
    }

    return \@cols;
}

1;

__END__

=head1 SUBROUTINES/METHODS

=head2 method build_header_msgstr

=head2 method split_header_msgstr

=cut