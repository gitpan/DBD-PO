package Test::DBD::PO::Defaults;

use strict;
use warnings;

#use Carp qw(confess); $SIG{__DIE__} = \&confess;
use Cwd;
use Socket qw($LF $CRLF);

our $TRACE = 1;
our $DROP_TABLE = 1;

our ($PATH) = getcwd() =~ m{(.*)}xms;
$PATH =~ s{\\}{/}xmsg;
our $SEPARATOR = $LF;
our $EOL       = $CRLF;
our $TABLE_0X  = 'po_test.po';
our $TABLE_11  = 'po_crash.po';
our $TABLE_12  = 'po_more_tables_?.po';
our $TABLE_13  = 'po_charset_?.po';
our $FILE_0X   = "$PATH/$TABLE_0X";
our $FILE_11   = "$PATH/$TABLE_11";
our $FILE_12   = "$PATH/$TABLE_12";
our $FILE_13   = "$PATH/$TABLE_13";

sub trace_file_name {
    my ($number) = (caller 0)[1] =~ m{\b (\d\d) \w+ \. t}xms;

    return "$PATH/trace_$number.txt";
}

=head1 NAME

Test::DBD::PO::Defaults - Some defaults to run tests for module DBD::PO

$Id: PO.pm 80 2008-07-26 17:25:03Z steffenw $

$HeadURL: https://dbd-po.svn.sourceforge.net/svnroot/dbd-po/trunk/DBD-PO/lib/DBD/PO.pm $

=head1 SUBROUTINES/METHOD

=head2 sub trace_file_name

    my $filename_for_trace = trace_file_name();

=cut
