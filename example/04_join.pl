#!perl
# $Id: 04_join.pl 315 2008-12-17 21:09:23Z steffenw $

use strict;
use warnings;

our $VERSION = 0;

use Carp qw(croak);
use English qw(-no_match_vars $OS_ERROR);
use DBI ();

# for test examples only
our $PATH;
() = eval 'use Test::DBD::PO::Defaults qw($PATH)'; ## no critic (StringyEval InterpolationOfMetachars)

my $path = $PATH
           || q{.};
my $table1 = 'de';
my $table2 = 'ru';
my $table3 = 'de_to_ru';

# write a file to disk only
{
    my $file_name = "$path/$table1.po";
    open my $file, '>', $file_name ## no critic (BriefOpen)
        or croak "Can't open file $file_name: $OS_ERROR";
    print {$file} <<'EOT' or croak "Can't write file $file_name: $OS_ERROR";
msgid ""
msgstr ""
"Content-Type: text/plain; charset=utf-8\n"
"Content-Transfer-Encoding: 8bit"

msgid "text 1 en"
msgstr "text 1 de"

msgid "text 2 en"
msgstr "text 3 de"

msgid "text3 en"
msgstr "text3 de"


EOT
}

# write a file to disk only
{
    my $file_name = "$path/$table2.po";
    open my $file, '>', $file_name ## no critic (BriefOpen)
        or croak "Can't open file $file_name: $OS_ERROR";
    print {$file} <<'EOT' or croak "Can't write file $file_name: $OS_ERROR";
msgid ""
msgstr ""
"Content-Type: text/plain; charset=utf-8\n"
"Content-Transfer-Encoding: 8bit"

msgid "text 1 en"
msgstr "text 1 ru"

msgid "text 2 en"
msgstr "text 3 ru"

msgid "text3 en"
msgstr "text3 ru"


EOT
}

# connect to database (directory)
my $dbh = DBI->connect(
    "DBI:PO:f_dir=$path;po_charset=utf-8",
    undef,
    undef,
    {
        RaiseError => 1,
        PrintError => 0,
    },
) or croak 'Cannot connect: ' . DBI->errstr();

# create the joined po file (table)
$dbh->do(<<"EOT");
    CREATE TABLE $table3.po
    (
        msgid  VARCHAR,
        msgstr VARCHAR
    )
EOT

# prepare to write the joined po file (table)
my $sth_insert = $dbh->prepare(<<"EOT");
    INSERT INTO $table3.po
    (msgid, msgstr)
    VALUES (?, ?)
EOT

# build and write the header of the joined po file (table)
$sth_insert->execute(
    q{},
    $dbh->func(
        undef,                 # minimized
        'build_header_msgstr', # function name
    ),
);

# Join table can not handle "filename.suffix" as table name
# but "filename" is ok.
cut_file_name_suffix();

# require joined data
my $sth_select = $dbh->prepare(<<"EOT");
    SELECT $table1.msgstr, $table2.msgstr
    FROM $table1
    INNER JOIN $table2 ON $table1.msgid = $table2.msgid
    WHERE $table1.msgid <> ''
EOT
$sth_select->execute();

# rename back the po files
restore_file_name_suffix();

# get the joined data
while ( my @data = $sth_select->fetchrow_array() ) {
    $sth_insert->execute(@data);
}

# all done
$dbh->disconnect();

sub cut_file_name_suffix {
    rename "$path/$table1.po", "$path/$table1";
    rename "$path/$table2.po", "$path/$table2";

    return;
}

sub restore_file_name_suffix {
    rename "$path/$table1", "$path/$table1.po";
    rename "$path/$table2", "$path/$table2.po";

    return;
}

# do it in case of error too
END {
    restore_file_name_suffix();
}