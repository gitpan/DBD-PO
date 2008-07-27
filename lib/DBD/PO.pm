package DBD::PO;

use strict;
use warnings;

use parent qw(DBD::File);

use DBD::PO::dr;
use DBD::PO::db;
use DBD::PO::Statement;
use DBD::PO::Table;
use DBD::PO::st;

our $VERSION = '0.04';

our $drh = ();       # holds driver handle once initialised
our $err = 0;        # holds error code   for DBI::err
our $errstr = q{};   # holds error string for DBI::errstr
our $sqlstate = q{}; # holds error state  for DBI::state

1;

__END__

=head1 NAME

DBD::PO - DBI driver for PO files

$Id: PO.pm 80 2008-07-26 17:25:03Z steffenw $

$HeadURL: https://dbd-po.svn.sourceforge.net/svnroot/dbd-po/trunk/DBD-PO/lib/DBD/PO.pm $

=head1 VERSION

0.01

=head1 SYNOPSIS

=head2 connect

    use DBI;
    use Socket qw($LF);

    $dbh = DBI->connect(
        'DBI:PO:'
        . 'f_dir=dir_x;'      # optional:
                              #  The default database is './',
                              #  here set to the directory 'dir_x'.
        . "po_separator=\n;"  # optional:
                              #  The default 'po_separator' to set/get
                              #  concatinated data is "\n",
                              #  here set to "\n" unnecessary.
        . "po_eol=$LF;"       # optional:
                              #  The default 'po_eol' (po end of line)
                              #  is network typical like 'use Socket qw($CRLF)',
                              #  here set to $LF like 'use Socket qw($LF)'.
        . 'po_charset=utf-8', # optional:
                              #  The default 'po_charset' is 'utf-8',
                              #  here set to 'utf-8' unnecessary.
        undef,                # Username is not used.
        undef,                # Password is not used.
        { RaiseError => 1 },  # The easy way to handle exceptions.
    ) or die 'Cannot connect: ' . $DBI->errstr();

=head2 create table

Note that currently only the column names will be stored and no other data.
Thus all other information including column type (INTEGER or CHAR(x),
for example), column attributes (NOT NULL, PRIMARY KEY, ...)
will silently be discarded.

Table names cannot be arbitrary, due to restrictions of the SQL syntax.
I recommend that table names are valid SQL identifiers: The first
character is alphabetic, followed by an arbitrary number of alphanumeric
characters. If you want to use other files, the file names must start
with '/', './' or '../' and they must not contain white space.

For conditional execution use CREATE TABLE IF EXISTS statement.

Columns:

=over 9

=item * comment

translator comment text concatinated by 'separator'

=item * automatic

automatic comment text concatinated by 'separator'

=item * reference

where the text to translate is from, concatinated by 'separator'

=item * obsolete

the translation is used (0) or not (1)

=item * fuzzy

the translation is finished (0) or not (1)

=item * c_format (c-format, no-c-format)

format flag, not set (0), set (1) or negative set (-1)

=item * php_format (php-format, no-php-format)

format flag, not set (0), set (1) or negative set (-1)

=item * msgid

the text to translate (emty string for header)

=item * msgstr

the translation

=back

    $dbh->do(<<'EOT');
        CREATE TABLE
            table.po (
                comment    VARCHAR,
                automatic  VARCHAR,
                reference  VARCHAR,
                obsolete   INTEGER,
                fuzzy      INTEGER,
                c_format   INTEGER,
                php_format INTEGER,
                msgid      VARCHAR,
                msgstr     VARCHAR
            )
    EOT

=head2 write the header

=head3 build msgstr

Minimized example:

The charset will set to the 'po_charset' given at the connect method
or to the default 'utf-8'.

    my $header_msgstr = $dbh->func(
        undef,
        # function name
        'build_header_msgstr',
    );

Full example:

    my $header_msgstr = $dbh->func(
        [
            # project
            'Project name',
            # ISO time format like yyyy-mmm-dd hh::mm:ss +00:00
            'the POT creation date',
            'the PO revision date',
            # last translator name and mail address
            [
                'Steffen Winkler',
                'steffenw@cpan.org',
            ],
            # language team, name and mail address
            [
                'MyTeam',
                'cpan@perl.org',
            ],
            # undef to accept the defaut settings
            undef, # mime version (1.0)
            undef, # content type (text/plain)
                   # and charset 'utf-8' or given at the connect method)
            undef, # content transfer encoding (8bit)
            # place here pairs for extra parameters
            [qw(
                X-Poedit-Language      German
                X-Poedit-Country       GERMANY
                X-Poedit-SourceCharset utf-8
            )],
        ],
        # function name
        'build_header_msgstr',
    );

=head2 write header row

Write the header row always at first!

    use Socket qw($CRLF);
    my $separator = $CRLF;

    my $header_comment = join(
        $separator,
        'This is a translator comment for the header.',
        'And this is line 2 of.',
    );

    $dbh->do(<<'EOT', undef, $header_comment, $header_msgstr);
        INSERT INTO table.po (
            comment,
            msgstr
        ) VALUES (?, ?)
EOT

=head2 write a row

Note the use of the quote method for escaping the word 'foobar'. Any
string must be escaped, even if it doesn't contain binary data.

    my $sth = $dbh->prepare(<<'EOT');
        INSERT INTO table.po (
            msgid,
            msgstr,
            reference
        ) VALUES (?, ?, ?)
    EOT

    $sth->execute(
        join(
            $separator,
            'text to translate',
            '2nd line of text',
        ),
        join(
            $separator,
            'translation',
            '2nd line of translation',
        ),
        join(
            $separator,
            'my_program: 17',
            'my_program: 269',
        ),
    );

=head2 read the header

    $sth = $dbh->prepare(<<'EOT');
        SELECT msgstr
        FROM   table.po
        WHERE  msgid = ''
    EOT

    $sth->execute();

    ($header_msgstr) = $sth->fetchrow_array();

=head2 read a row

    $sth = $dbh->prepare(<<'EOT');
        SELECT msgstr
        FROM   table.po
        WHERE  msgid = ?
    EOT

    $sth->execute(
        join(
            $separator,
            'text to translate',
            '2nd line of text',
        ),
    );

    my ($msgstr) = $sth->fetchrow_array();

=head3 extract the header data

    my $header_struct = $dbh->func(
        $header_msgstr,
        # function name
        'split_header_msgstr',
    );

=head2 update rows

    $dbh->do(<<'EOT');
        UPDATE table.po
        SET    msgstr = '',
               fuzzy = 1
        WHERE  msgid = 'my_id'
    EOT

=head2 delete rows

    $dbh->do(<<'EOT');
        DELETE FROM table.po
        WHERE       obsolete = 1
    EOT

=head2 drop table

For conditional execution use DROP TABLE IF EXISTS statement.

    $dbh->do(<<'EOT');
        DROP TABLE table.po
    EOT

=head2 disconnect

    $dbh->disconnect();

=head1 DESCRIPTION

The DBD::PO module is yet another driver for the DBI
(Database independent interface for Perl).
This one is based on the SQL 'engine' SQL::Statement
and the abstract DBI driver DBD::File and implements access to
so-called PO files (GNU gettext).
Such files are readable by Locale::Maketext.

See DBI for details on DBI, L<SQL::Statement> for details on
SQL::Statement and L<DBD::File> for details on the base class
DBD::File.

=head1 SUBROUTINES/METHODS

nothing in this module

=head1 DIAGNOSTICS

see DBI

=head1 CONFIGURATION AND ENVIRONMENT

see DBI

=head1 DEPENDENCIES

Carp

Socket

parent

DBI

L<SQL::Statement>

L<Params::Validate>

=head2 Prerequisites

The only system dependent feature that DBD::File uses, is the C<flock()>
function. Thus the module should run (in theory) on any system with
a working C<flock()>, in particular on all Unix machines and on Windows
NT. Under Windows 95 and MacOS the use of C<flock()> is disabled, thus
the module should still be usable,

Unlike other DBI drivers, you don't need an external SQL engine
or a running server. All you need are the following Perl modules,
available from any CPAN mirror.

=head2 SQL

The level of SQL support available depends on the version of
SQL::Statement installed.
Any version will support *basic*
CREATE, INSERT, DELETE, UPDATE, and SELECT statements.
Only versions of SQL::Statement 1.0 and above support additional
features such as table joins, string functions, etc.
See the documentation of the latest version of SQL::Statement for details.

=head1 INCOMPATIBILITIES

not known

=head1 BUGS AND LIMITATIONS

The module is using flock() internally. However, this function is not
available on platforms. Using flock() is disabled on MacOS and Windows
95: There's no locking at all (perhaps not so important on these
operating systems, as they are for single users anyways).

=head1 SEE ALSO

DBI

L<DBD::File>

L<Locale::PO>

L<DBD::CSV>

=head1 AUTHOR

Steffen Winkler

=head1 LICENSE AND COPYRIGHT

Copyright (c) 2008,
Steffen Winkler
C<< <steffenw@cpan.org> >>.
All rights reserved.

This module is free software;
you can redistribute it and/or modify it
under the same terms as Perl itself.

=cut