package Test::DBD::PO::Defaults;

use strict;
use warnings;

our $VERSION = '2.00';

use parent qw(Exporter);
our @EXPORT_OK = qw(
    $TRACE
    $DROP_TABLE

    $PATH
    $SEPARATOR
    $EOL

    $TABLE_0X
    $TABLE_11
    $TABLE_12
    $TABLE_13
    $TABLE_14
    $TABLE_15
    $TABLE_2X

    $FILE_LOCALE_PO_01
    $FILE_LOCALE_PO_02
    $FILE_TEXT_PO
    $FILE_0X
    $FILE_11
    $FILE_12
    $FILE_13
    $FILE_14
    $FILE_15
    $FILE_2X

    trace_file_name
    run_example
);

use Carp qw(croak);
use English qw(-no_match_vars $OS_ERROR $EVAL_ERROR $INPUT_RECORD_SEPARATOR);
use Cwd;
use Socket qw($LF $CRLF);

our $TRACE = 1;
our $DROP_TABLE = 1;

our ($PATH) = getcwd() =~ m{(.*)}xms;
$PATH =~ s{\\}{/}xmsg;
our $SEPARATOR       = $LF;
our $EOL             = $CRLF;

my  $TABLE_LOCALE_PO_01 = 'locale_po_01.po';
my  $TABLE_LOCALE_PO_02 = 'locale_po_02.po';
my  $TABLE_TEXT_PO      = 'text_po.po';
our $TABLE_0X           = 'dbd_po_test.po';
our $TABLE_11           = 'dbd_po_crash.po';
our $TABLE_12           = 'dbd_po_more_tables_?.po';
our $TABLE_13           = 'dbd_po_charset_?.po';
our $TABLE_14           = 'dbd_po_quote.po';
our $TABLE_15           = 'dbd_po_header_msgstr_hash.po';
our $TABLE_2X           = 'table_xx.po';

our $FILE_LOCALE_PO_01 = "$PATH/$TABLE_LOCALE_PO_01";
our $FILE_LOCALE_PO_02 = "$PATH/$TABLE_LOCALE_PO_02";
our $FILE_TEXT_PO      = "$PATH/$TABLE_TEXT_PO";
our $FILE_0X           = "$PATH/$TABLE_0X";
our $FILE_11           = "$PATH/$TABLE_11";
our $FILE_12           = "$PATH/$TABLE_12";
our $FILE_13           = "$PATH/$TABLE_13";
our $FILE_14           = "$PATH/$TABLE_14";
our $FILE_15           = "$PATH/$TABLE_15";
our $FILE_2X           = "$PATH/$TABLE_2X";

sub trace_file_name {
    my ($number) = (caller 0)[1] =~ m{\b (\d\d) \w+ \. t}xms;

    return "$PATH/trace_$number.txt";
}

sub run_example {
    my $file_name = shift;

    open my $file, '<', "$PATH/example/$file_name"
        or croak $OS_ERROR;
    local $INPUT_RECORD_SEPARATOR = ();
    my ($content) = <$file> =~ m{\A (.*) \z}xms; # untaint
    () = close $file;
    () = eval $content; ## no critic (ProhibitStringyEval)

    return $EVAL_ERROR;
}

1;

__END__

=head1 NAME

Test::DBD::PO::Defaults - Some defaults to run tests for module DBD::PO

$Id: Defaults.pm 289 2008-11-09 13:10:28Z steffenw $

$HeadURL: https://dbd-po.svn.sourceforge.net/svnroot/dbd-po/trunk/DBD-PO/lib/Test/DBD/PO/Defaults.pm $

=head1 VERSION

2.00

=head1 SYNOPSIS

    use Test::DBD::PO::Defaults qw(
        # see @EXPORT_OK in source
    );

=head1 DESCRIPTION

This module is only useful for the test of DBD::PO module.

=head1 SUBROUTINES/METHODS

=head2 sub trace_file_name

    my $filename_for_trace = trace_file_name();

=head2 sub run_example

    my $error = run_example('example_file_name_without_path');

=head1 DIAGNOSTICS

none

=head1 CONFIGURATION AND ENVIRONMENT

none

=head1 DEPENDENCIES

Carp

English

Cwd

Socket

=head1 INCOMPATIBILITIES

not known

=head1 BUGS AND LIMITATIONS

not known

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