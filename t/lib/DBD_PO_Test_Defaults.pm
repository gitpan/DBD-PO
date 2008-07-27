package DBD_PO_Test_Defaults;

#use Carp qw(confess); $SIG{__DIE__} = \&confess;
use Cwd;
use Socket qw($LF $CRLF);

our $TRACE = 1;

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