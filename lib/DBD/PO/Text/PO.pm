package DBD::PO::Text::PO;

use strict;
use warnings;

our $VERSION = '1.00';

use Carp qw(croak);
use English qw(-no_match_vars $OS_ERROR);
use Params::Validate qw(:all);
use DBD::PO::Locale::PO;
use Socket qw($CRLF);

use parent qw(Exporter);
our @EXPORT_OK = qw(
    $EOL_DEFAULT
    $SEPARATOR_DEFAULT
    $CHARSET_DEFAULT
    @COL_NAMES
);

our $EOL_DEFAULT       = $CRLF;
our $SEPARATOR_DEFAULT = "\n";
our $CHARSET_DEFAULT   = 'iso-8859-1';

my @cols = (
    [ qw( msgid      -msgid      msgid      ) ],
    [ qw( msgstr     -msgstr     msgstr     ) ],
    [ qw( comment    -comment    comment    ) ],
    [ qw( automatic  -automatic  automatic  ) ],
    [ qw( reference  -reference  reference  ) ],
    [ qw( obsolete   -obsolete   obsolete   ) ],
    [ qw( fuzzy      -fuzzy      fuzzy      ) ],
    [ qw( c_format   -c-format   c_format   ) ],
    [ qw( php_format -php-format php_format ) ],
);
our @COL_NAMES       = map {$_->[0]} @cols;
my  @COL_PARAMETERS  = map {$_->[1]} @cols;
my  @COL_METHODS     = map {$_->[2]} @cols;

my $dequote = sub {
    my $string = shift;

    return if $string eq 'NULL';
    if ($string =~ s{\A _Q_U_O_T_E_D_:}{}xms) {
        $string =~ s{\\\\}{\\}xmsg;
    }

    return $string;
};

my $array_from_anything = sub {
    my ($self, $anything) = @_;

    my @array = map { ## no critic (ComplexMappings)
        my $dequoted = $dequote->($_);
        split m{\Q$self->{separator}\E}xms, $dequoted;
    } ref $anything eq 'ARRAY'
      ? @{$anything}
      : defined $anything
        ? $anything
        : ();

    return \@array;
};

sub new { ## no critic (RequireArgUnpacking)
    my ($class, $options) = validate_pos(
        @_,
        {type => SCALAR},
        {type => HASHREF},
    );
    $options = validate_with(
        params => $options,
        spec   => {
            eol       => {default  => $EOL_DEFAULT},
            separator => {default  => $SEPARATOR_DEFAULT},
            charset   => {optional => 1},
        },
        called => "2nd parameter of new('$class', \$parameter)",
    );

    if ($options->{charset}) {
        $options->{encoding} = ":encoding($options->{charset})";
    }

    return bless $options, $class;
}

sub write_entry { ## no critic (ExcessComplexity)
    my ($self, $file_name, $file_handle, $col_ref) = @_;

    my %line;
    for my $index (0 .. $#COL_NAMES) {
        my $parameter = $COL_PARAMETERS[$index];
        my $values    = $array_from_anything->($self, $col_ref->[$index]);
        if (
            $parameter eq '-comment'
            || $parameter eq '-automatic'
            || $parameter eq '-reference'
        ) {
            if (@{$values}) {
                $line{$parameter} = join $self->{eol}, @{$values};
            }
        }
        elsif (
            $parameter eq '-obsolete'
            || $parameter eq '-fuzzy'
        ) {
            $line{$parameter} = $values->[0] ? 1 : 0;
        }
        elsif (
            $parameter eq '-c-format'
            || $parameter eq '-php-format'
        ) {
            my $flag = $values->[0];
            # translate:
            # perl_false => nothing set
            # -something => -no-flag = 1
            # something  => -flag = 1
            if ($flag) {
                $line{
                    (
                        $flag =~ m{\A -}xms
                        ? '-no'
                        : q{}
                    )
                    . $parameter
                } = 1;
            }
        }
        else {
            if ( @{$values} ) {
                $line{$parameter} = join "\n", @{$values};
                if (! tell $file_handle) {
                    if ($parameter eq '-msgid') {
                        croak 'A header has no msgid';
                    }
                    else { # -msgstr
                        if ($line{$parameter} !~ m{\b charset =}xms) { ## no critic (DeepNests)
                            croak 'This can not be a header';
                        }
                    }
                }
            }
            else {
                if ($parameter eq '-msgid' && tell $file_handle) {
                    croak 'A line has to have a msgid';
                }
                elsif ($parameter eq '-msgstr' && ! tell $file_handle
                ) {
                    croak 'A header has to have a msgstr';
                }
            }
        }
        ++$index;
    }
    my $line = DBD::PO::Locale::PO->new(
        eol       => $self->{eol},
        '-msgid'  => q{},
        '-msgstr' => q{},
        %line,
    )->dump();
    print {$file_handle} $line
        or croak "Print $file_name: $OS_ERROR";

    return $self;
}

sub read_entry { ## no critic (ExcessComplexity)
    my ($self, $file_name, $file_handle) = @_;

    if (! defined $self->{line_number}) {
        $self->{line_number} = 0;
    }
    my $po = DBD::PO::Locale::PO->load_entry(
        $file_name,
        $file_handle,
        \$self->{line_number},
        $self->{eol},
    );
    # EOF
    if (! $po) {
        delete $self->{line_number};
        return [];
    }
    # run a line, it is a po object
    my @cols;
    my $index = 0;
    METHOD:
    for my $method (@COL_METHODS) {
        if (
            $method eq 'comment'
            || $method eq 'automatic'
            || $method eq 'reference'
        ) {
            my $comment = $po->$method();
            $cols[$index]
                = defined $comment
                  ? (
                      join  $self->{separator},
                      split m{\Q$self->{eol}\E}xms,
                      $comment
                  )
                  : q{};
        }
        elsif (
            $method eq 'obsolete'
            || $method eq 'fuzzy'
        ) {
            $cols[$index] = $po->$method() ? 1 : 0;
        }
        elsif (
            $method eq 'c_format'
            || $method eq 'php_format'
        ) {
            my $flag = $po->$method();
            # translate:
            # undef => 0
            # 0     => -1
            # 1     => 1
            $cols[$index] = defined $flag
                            ? (
                                $flag ? 1 : -1 ## no critic (MagicNumbers)
                            )
                            : 0;
        }
        else {
            $cols[$index]
                = join  $self->{separator},
                  split m{\\n}xms,
                        $po->$method();
        }
        ++$index;
    }

    return \@cols;
}

1;

__END__

=head1 NAME

DBD::PO::Text::PO - read or write a PO file entry by entry

$Id: PO.pm 254 2008-10-21 19:11:47Z steffenw $

$HeadURL: https://dbd-po.svn.sourceforge.net/svnroot/dbd-po/trunk/DBD-PO/lib/DBD/PO/Text/PO.pm $

=head1 VERSION

1.00

=head1 SYNOPSIS

=head2 write

    use strict;
    use warnings;

    use Carp qw(croak);
    use English qw(-no_match_vars $OS_ERROR);
    require IO::File;
    require DBD::PO::Text::PO;

    my $file_handle = IO::File->new();
    $file_handle->open(
        $file_name,
        '> :encoding(utf-8)',
    ) or croak "Can not open file $file_name: $OS_ERROR;
    my $text_po = DBD::PO::Text::PO->new({
        eol     => "\n",
        charset => 'utf-8',
    });

    # header
    $text_po->write_entry(
        $file_name,
        $file_handle,
        [
            q{},
            'Content-Type: text/plain; charset=utf-8',
        ],
    );

    # line
    $text_po->write_entry(
        $file_name,
        $file_handle,
        [
            'id',
            'text',
        ],
    );

=head2 read

    use strict;
    use warnings;

    use Carp qw(croak);
    use English qw(-no_match_vars $OS_ERROR);
    require IO::File;
    require DBD::PO::Text::PO;

    my $file_handle = IO::File->new();
    $file_handle->open(
        $file_name,
        '< :encoding(utf-8)',
    ) or croak "Can not open file $file_name: $OS_ERROR;
    my $text_po = DBD::PO::Text::PO->new({
        eol     => "\n",
        charset => 'utf-8',
    });

    # header
    my $header_array_ref = $text_po->read_entry($file_name, $file_handle);

    # line
    while ( @{ my $array_ref = $text_po->read_entry($file_name, $file_handle) } ) {
        print "id: $array_ref->[0], text: $array_ref->[1]\n";
    }

=head1 DESCRIPTION

The DBD::PO::Text::PO was written as wrapper between
DBD::PO and DBD::PO::Locale::PO.

     ---------------------
    |         DBI         |
     ---------------------
               |
     ---------------------
    |      DBD::File      |
    |  (SQL::Statement)   |
     ---------------------
               |
     ---------------------
    |       DBD::PO       |
     ---------------------
               |
     ---------------------
    |  DBD::PO::Text::PO  |
     ---------------------
               |
     ---------------------
    | DBD::PO::Locale::PO |
     ---------------------
               |
         table_file.po

=head1 SUBROUTINES/METHODS

=head2 method new

=head2 method write_entry

=head2 method read_entry

=head1 DIAGNOSTICS

none

=head1 CONFIGURATION AND ENVIRONMENT

none

=head1 DEPENDENCIES

Carp

English

L<Params::Validate>

L<DBD::PO::Locale::PO>

Socket

=head1 INCOMPATIBILITIES

not known

=head1 BUGS AND LIMITATIONS

not known

=head1 SEE ALSO

L<DBD::CSV>

=head1 AUTHOR

Steffen Winkler

=head1 LICENSE AND COPYRIGHT

Copyright (c) 2008,
Steffen Winkler
C<< <steffenw at cpan.org> >>.
All rights reserved.

This module is free software;
you can redistribute it and/or modify it
under the same terms as Perl itself.

=cut