package DBD::PO::db; # DATABASE

use strict;
use warnings;

use DBD::File;
use parent qw(-norequire DBD::File::db);

use Carp qw(croak);
use Params::Validate qw(:all);
use Storable qw(dclone);
use SQL::Statement; # for SQL::Parser
use SQL::Parser;
use DBD::PO::Locale::PO;
use DBD::PO::Text::PO qw($EOL_DEFAULT $SEPARATOR_DEFAULT $CHARSET_DEFAULT);

our $imp_data_size = 0;

my @header = (
    [ project_id_version        => 'Project-Id-Version: %s'        ],
    [ pot_creation_date         => 'POT-Creation-Date: %s'         ],
    [ po_revision_date          => 'PO-Revision-Date: %s'          ],
    [ last_translator           => 'Last-Translator: %s <%s>'      ],
    [ language_team             => 'Language-Team: %s <%s>'        ],
    [ mime_version              => 'MIME-Version: %s'              ],
    [ content_type              => 'Content-Type: %s; charset=%s'  ],
    [ content_transfer_encoding => 'Content-Transfer-Encoding: %s' ],
    [ extended                  => '%s: %s'                        ],
);
my @HEADER_KEYS     = map {$_->[0]} @header;
my @HEADER_FORMATS  = map {$_->[1]} @header;
my @HEADER_DEFAULTS = (
    undef,
    undef,
    undef,
    undef,
    undef,
    '1.0',
    ['text/plain', undef],
    '8bit',
    undef,
);
my @HEADER_REGEX = (
    qr{\A \QProject-Id-Version:\E        \s (.*) \z}xmsi,
    qr{\A \QPOT-Creation-Date:\E         \s (.*) \z}xmsi,
    qr{\A \QPO-Revision-Date:\E          \s (.*) \z}xmsi,
    qr{\A \QLast-Translator:\E           \s ([^<]*) \s < ([^>]*) > }xmsi,
    qr{\A \QLanguage-Team:\E             \s ([^<]*) \s < ([^>]*) > }xmsi,
    qr{\A \QMIME-Version:\E              \s (.*) \z}xmsi,
    qr{\A \QContent-Type:\E              \s ([^;]*); \s charset=(\S*) }xmsi,
    qr{\A \QContent-Transfer-Encoding:\E \s (.*) \z}xmsi,
    qr{\A ([^:]*):                       \s (.*) \z}xms,
);

my $maketext_to_gettext_scalar = sub {
    my $string = shift;

    defined $string
        or return;
    $string =~ s{
        \[ \s*
        (?:
            ( [A-Za-z*\#] [A-Za-z_]* ) # $1 - function call
            \s* , \s*
            _ ( [1-9]\d* )             # $2 - variable
            ( [^\]]* )                 # $3 - arguments
            |                          # or
            _ ( [1-9]\d* )             # $4 - variable
        )
        \s* \]
    }
    {
        $4 ? "%$4" : "%$1(%$2$3)"
    }xmsge;

    return $string;
};

sub maketext_to_gettext {
    my($self, @strings) = @_;

    return
        @strings > 1
        ? map { $maketext_to_gettext_scalar->($_) } @strings
        : @strings
          ? $maketext_to_gettext_scalar->( $strings[0] )
          : ();
}

sub quote {
    my($self, $string, $type) = @_;

    defined $string
        or return 'NULL';
    if (
        defined($type)
        && (
            $type == DBI::SQL_NUMERIC()
            || $type == DBI::SQL_DECIMAL()
            || $type == DBI::SQL_INTEGER()
            || $type == DBI::SQL_SMALLINT()
            || $type == DBI::SQL_FLOAT()
            || $type == DBI::SQL_REAL()
            || $type == DBI::SQL_DOUBLE()
            || $type == DBI::SQL_TINYINT()
        )
    ) {
        return $string;
    }
    my $is_quoted;
    for (
        $string =~ s{\\}{\\\\}xmsg,
        $string =~ s{'}{\\'}xmsg,
    ) {
       $is_quoted ||= $_;
    }

    return $is_quoted
           ? "'_Q_U_O_T_E_D_:$string'"
           : "'$string'";
}

my %hash2array = (
    'Project-Id-Version'        => 0,
    'POT-Creation-Date'         => 1,
    'PO-Revision-Date'          => 2,
    'Last-Translator-Name'      => [3, 0],
    'Last-Translator-Mail'      => [3, 1],
    'Language-Team-Name'        => [4, 0],
    'Language-Team-Mail'        => [4, 1],
    'MIME-Version'              => 5,
    'Content-Type'              => [6, 0],
    charset                     => [6, 1],
    'Content-Transfer-Encoding' => 7,
);
my $index_extended = 8;

my $valid_keys_regex = '(?xsm-i:\A (?: '
                       . join(
                           '|',
                           map {
                               quotemeta $_
                           } keys %hash2array, 'extended'
                       )
                       . ' ) \z)';

sub _hash2array {
    caller eq __PACKAGE__
        or croak 'Do not call a private sub';
    my ($hash_data, $charset) = @_;
    validate_with(
        params => $hash_data,
        spec   => {
            (
                map {
                    ($_ => => {type => SCALAR, optional => 1});
                } keys %hash2array
            ),
            extended => {type => ARRAYREF, optional => 1},
        },
    );

    my $array_data = dclone(\@HEADER_DEFAULTS);
    $array_data->[ $hash2array{charset}->[0] ]->[$hash2array{charset}->[1] ]
        = $charset;
    KEY:
    for my $key (keys %{$hash_data}) {
        if ($key eq 'extended') {
            $array_data->[$index_extended] = $hash_data->{extended};
            next KEY;
        }
        if (ref $hash2array{$key} eq 'ARRAY') {
            $array_data->[ $hash2array{$key}->[0] ]->[ $hash2array{$key}->[1] ]
                = $hash_data->{$key};
            next KEY;
        }
        $array_data->[ $hash2array{$key} ] = $hash_data->{$key};
    }

    return $array_data;
};

sub build_header_msgstr {
    my ($dbh, $anything) = validate_pos(
        @_,
        {isa   => 'DBI::db'},
        {type  => UNDEF | ARRAYREF | HASHREF},
    );

    my $charset = $dbh->FETCH('po_charset')
                  ? $dbh->FETCH('po_charset')
                  : $CHARSET_DEFAULT;
    my $array_data = ref $anything eq 'HASH'
                     ? _hash2array($anything, $charset)
                     : $anything;
    my @header;
    HEADER_KEY:
    for my $index (0 .. $#HEADER_KEYS) {
        my $data = $array_data->[$index]
                   || $HEADER_DEFAULTS[$index];
        defined $data
            or next HEADER_KEY;
        my $key    = $HEADER_KEYS[$index];
        my $format = $HEADER_FORMATS[$index];
        my @data = defined $data
                   ? (
                       ref $data eq 'ARRAY'
                       ? @{ $data }
                       : $data
                   )
                   : ();
        if ($key eq 'content_type') {
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
            push @header, sprintf $format, map {defined $_ ? $_ : q{}} @data;
        }
    }

    return join "\n", @header;
}

sub split_header_msgstr {
    my ($dbh, $anything) = validate_pos(
        @_,
        {isa   => 'DBI::db'},
        {type  => SCALAR | HASHREF},
    );

    my $msgstr;
    if (ref $anything eq 'HASH') {
        validate_with(
            params => my $hash_ref = $anything,
            spec   => {
                table => {type => SCALAR},
            },
        );
        my $sth = $dbh->prepare(<<"EOT") or croak $dbh->errstr();
            SELECT msgstr
            FROM $hash_ref->{table}
            WHERE msgid = ''
EOT
        $sth->execute()
            or croak $sth->errstr();
        ($msgstr) = $sth->fetchrow_array()
            or croak $sth->errstr();
        $sth->finish()
            or croak $sth->errstr();
    }
    else {
        $msgstr = $anything;
    }

    my $po = DBD::PO::Locale::PO->new(
        eol => defined $dbh->FETCH('eol')
               ? $dbh->FETCH('eol')
               : $EOL_DEFAULT,
    );
    my $separator = defined $dbh->FETCH('separator')
                    ? $dbh->FETCH('separator')
                    : $SEPARATOR_DEFAULT;
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
        for my $header_regex (@HEADER_REGEX) {
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

sub get_header_msgstr_data {
    my ($dbh, $anything, $key) = validate_pos(
        @_,
        {isa  => 'DBI::db'},
        {type => ARRAYREF | SCALAR | HASHREF},
        {
            type => SCALAR | ARRAYREF,
            callbacks => {
                check_keys => sub {
                    my $key = shift;
                    if (ref $key eq 'ARRAY') {
                        return 1;
                    }
                    else {
                        return $key =~ $valid_keys_regex;
                    }
                },
            },
        },
    );

    my $array_ref = (ref $anything eq 'ARRAY')
                    ? $anything
                    : $dbh->func($anything, 'split_header_msgstr');

    if (ref $key eq 'ARRAY') {
        return [
            map {
                get_header_msgstr_data($dbh, $array_ref, $_);
            } @{$key}
        ];
    }

    my $index = $key eq 'extended'
                ? $index_extended
                : $hash2array{$key};
    if (ref $index eq 'ARRAY') {
        return $array_ref->[ $index->[0] ]->[ $index->[1] ];
    }

    return $array_ref->[$index];
}

1;

__END__

=head1 SUBROUTINES/METHODS

=head2 method maketext_to_gettext

=head2 method quote

=head2 method build_header_msgstr

=head2 method split_header_msgstr

=head2 method get_header_msgstr_data

=cut