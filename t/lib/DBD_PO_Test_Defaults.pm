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
our $TABLE_1X  = 'po_crash.po';
our $FILE_0X   = "$PATH/$TABLE_0X";
our $FILE_1X   = "$PATH/$TABLE_1X";

sub trace_file_name {
    my ($number) = (caller 0)[1] =~ m{\b (\d\d) \w+ \. t}xms;

    return "$PATH/trace_$number.txt";
}
