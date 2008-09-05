#!perl -T

use strict;
use warnings;

use Test::DBD::PO::Defaults;
use Test::More tests => 7;
eval 'use Test::Differences qw(eq_or_diff)';
if ($@) {
    *eq_or_diff = \&is;
    diag("Module Test::Differences not installed; $@");
}

BEGIN {
    require_ok('IO::File');
    require_ok('DBD::PO::Text::PO');
}

my $test_string = join "\n", (
    (
        map {
            join q{}, map { chr $_ } 8 * $_ .. 8 * $_ + 7;
        } 0 .. 15
    ),
    (
        map {
            join q{}, map { "\\" . chr $_ } 8 * $_ .. 8 * $_ + 7;
        } 0 .. 15
    ),
);

sub quote {
    my $string = shift;
    my $eol    = shift;

    my %named = (
        #qq{\a} => qq{\\a}, # BEL
        #qq{\b} => qq{\\b}, # BS
        #qq{\t} => qq{\\t}, # TAB
        qq{\n} => qq{\\n}, # LF
        #qq{\f} => qq{\\f}, # FF
        #qq{\r} => qq{\\r}, # CR
        qq{"}  => qq{\\"},
        qq{\\} => qq{\\\\},
    );
    $string =~ s{
        ( [^ !#$%&'()*+,\-.\/0-9:;<=>?@A-Z\[\]\^_`a-z{|}~] )
    }{
        ord $1 < 0x80
        ? (
            exists $named{$1}
            ? $named{$1}
            : sprintf '\x%02x', ord $1
        )
        : $1;
    }xmsge;
    $string = qq{"$string"};
    # multiline
    if ($string =~ s{\A ( " .*? \\n )}{""\n$1}xms) {
        $string =~ s{\\n}{\\n"$eol"}xmsg;
    }

    return $string;
}

my $po_string = quote($test_string, "\n");

# write po file
{
    my $file = IO::File->new();
    isa_ok($file, 'IO::File');

    ok(
        $file->open(
            $Test::DBD::PO::Defaults::FILE_TEXT_PO,
            '> :encoding(utf-8)',
        ),
        'open file',
    );

    my $text_po = DBD::PO::Text::PO->new({
        eol     => "\n",
        charset => 'utf-8',
    });
    isa_ok($text_po, 'DBD::PO::Text::PO', 'new');

    # header
    $text_po->print(
        $file,
        [
            '',
            'Content-Type: text/plain; charset=utf-8',
        ],
    );

    # line
    $text_po->print(
        $file,
        [
            'id',
            $test_string,
        ],
    );
}

# check_table_file
{
    my $po = <<"EOT";
msgid ""
msgstr "Content-Type: text/plain; charset=utf-8"

msgid "id"
msgstr $po_string

EOT
    local $/ = ();
    open my $file1,
         '< :encoding(utf-8)',
         $Test::DBD::PO::Defaults::FILE_TEXT_PO or die $!;
    my $content1 = <$file1>;
    open my $file2, '< :encoding(utf-8)', \($po) or die $!;
    my $content2 = <$file2>;
    eq_or_diff($content1, $content2, 'check po file');
}

# drop table
SKIP: {
    skip('delete file', 1)
        if ! $Test::DBD::PO::Defaults::DROP_TABLE;

    unlink $Test::DBD::PO::Defaults::FILE_TEXT_PO;
    ok(! -e $Test::DBD::PO::Defaults::FILE_TEXT_PO, 'table file deleted');
}
