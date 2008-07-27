package DBD::PO::Text::PO;

use strict;
use warnings;

use Carp qw(croak);
use Params::Validate qw(:all);
use DBD::PO::Locale::PO;

my $array_from_anything = sub {
    my ($self, $anything) = @_;

    my @array = map {
        split m{\Q$self->{separator}\E}xms, $_;
    } ref $anything eq 'ARRAY'
      ? @{$anything}
      : defined $anything
        ? $anything
        : ();

    return \@array;
};

sub new {
    my ($class, $options) = validate_pos(
        @_,
        {type => SCALAR},
        {type => HASHREF},
    );
    $options = validate_with(
        params => $options,
        spec => {
            eol       => {default => $DBD::PO::dr::EOL_DEFAULT},
            separator => {default => $DBD::PO::dr::SEPARATOR_DEFAULT},
            charset   => {default => $DBD::PO::dr::CHARSET_DEFAULT},
        },
        called => "2nd parameter of new('$class', \$parameter)",
    );

    return bless $options, $class;
}

sub print {
    my ($self, $file, $col_ref) = validate_pos(
        @_,
        {isa => __PACKAGE__},
        {isa => 'IO::File'},
        {type => ARRAYREF},
    );

    $file->binmode(":encoding($self->{charset})")
        or croak "binmode: $!";
    my %line;
    for my $index (0 .. $#DBD::PO::dr::COL_NAMES) {
        my $parameter = $DBD::PO::dr::COL_PARAMETERS[$index];
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
            if (@{$values}) {
                $line{$parameter} = join "\\n", @{$values};
                if (! $file->tell()) {
                    if ($parameter eq '-msgid') {
                        croak 'A header has no msgid';
                    }
                    else { # -msgstr
                        if ($line{$parameter} !~ m{\b charset =}xms) {
                            croak 'This can not be a header';
                        }
                    }
                }
            }
            else {
                if ($parameter eq '-msgid' && $file->tell()) {
                    croak 'A line has to have a msgid';
                }
                elsif ($parameter eq '-msgstr' && ! $file->tell()) {
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
    $file->print(
        $line,
    );

    return 1;
}

sub getline {
    my ($self, $file) = validate_pos(
        @_,
        {isa => __PACKAGE__},
        {isa => 'IO::File'},
    );

    $file->binmode(":encoding($self->{charset})")
        or croak "binmode: $!";
    if (! $self->{po_iterator}) {
        $self->{po_iterator}
            = DBD::PO::Locale::PO->load_file_asarray($file, $self->{eol});
    }
    # EOF
    if (! @{ $self->{po_iterator} }) {
        delete $self->{po_iterator};
        return [];
    }
    # run a line, it is a po object
    my $po = shift @{ $self->{po_iterator} };
    my @cols;
    my $index = 0;
    METHOD:
    for my $method (@DBD::PO::dr::COL_METHODS) {
        if (
           $method eq 'comment'
           || $method eq 'automatic'
           || $method eq 'reference'
        ) {
            $cols[$index]
                = join  $self->{separator},
                  split m{\Q$self->{eol}\E}xms,
                        $po->dequote( $po->$method() );
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
                                $flag ? 1 : -1
                            )
                            : 0;
        }
        else {
            $cols[$index]
                = join  $self->{separator},
                  split m{\\n}xms,
                        $po->dequote( $po->$method() );
        }
        ++$index;
    }

    return \@cols;
}

1;

__END__

=head1 SUBROUTINES/METHODS

=head2 method new

=head2 method print

=head2 method getline

=cut