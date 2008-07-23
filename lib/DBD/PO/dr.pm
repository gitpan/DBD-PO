package DBD::PO::dr; # DRIVER

use strict;
use warnings;

use DBD::File;
use parent qw(-norequire DBD::File::dr);

use Socket qw($LF $CRLF);
use Readonly qw(Readonly);

Readonly my $PV => 0;
Readonly my $IV => 1;
Readonly my $NV => 2;

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

    my $dbh = $drh->DBD::File::dr::connect($dbname, $user, $auth, $attr);
    $dbh->{po_tables} ||= {};
    $dbh->{Active} = 1;

    return $dbh;
}

Readonly our $SEPARATOR_DEFAULT => $LF;
Readonly our $EOL_DEFAULT       => $CRLF;
Readonly our $CHARSET_DEFAULT   => 'utf-8';

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
our @COL_PARAMETERS  = map {$_->[1]} @cols;
our @COL_METHODS     = map {$_->[2]} @cols;

my @header = (
    [ project_id_version        => 'Project-Id-Version: %s',                               ],
    [ pot_creation_date         => 'POT-Creation-Date: %s',                                ],
    [ po_revision_date          => 'PO-Revision-Date: %s',                                 ],
    [ last_translator           => 'Last-Translator: %s <%s>',                             ],
    [ language_team             => 'Language-Team: %s <%s>',                               ],
    [ mime_version              => 'MIME-Version: %s',              '1.0'                  ],
    [ content_type              => 'Content-Type: %s; charset=%s', ['text/plain', 'utf-8'] ],
    [ content_transfer_encoding => 'Content-Transfer-Encoding: %s', '8bit'                 ],
    [ extended                  => '%s: %s',                                               ],
);
our @HEADER_KEYS     = map {$_->[0]} @header;
our @HEADER_FORMATS  = map {$_->[1]} @header;
our @HEADER_DEFAULTS = map {$_->[2]} @header;
our @HEADER_REGEX = (
    qr{\A \QProject-Id-Version:\E        \s (.*) \z}xms,
    qr{\A \QPOT-Creation-Date:\E         \s (.*) \z}xms,
    qr{\A \QPO-Revision-Date:\E          \s (.*) \z}xms,
    qr{\A \QLast-Translator:\E           \s ([^<]*) \s < ([^>]*) > }xms,
    qr{\A \QLanguage-Team:\E             \s ([^<]*) \s < ([^>]*) > }xms,
    qr{\A \QMIME-Version:\E              \s (.*) \z}xms,
    qr{\A \QContent-Type:\E              \s ([^;]*); \s charset=(\S*) }xms,
    qr{\A \QContent-Transfer-Encoding:\E \s (.*) \z}xms,
    qr{\A ([^:]*):                       \s (.*) \z}xms,
);

1;

__END__

=head1 SUBROUTINES/METHOD

=head2 method connect

=cut
