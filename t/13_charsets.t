#!perl -T

use strict;
use warnings;

use lib qw(./t/lib D:/workspace/DBD-PO/trunk/DBD-PO/t/lib);
use DBD_PO_Test_Defaults;

use Test::More tests => 17;
my $module = 'Test::Differences';
eval "use $module";
if ($@) {
    *eq_or_diff = \&is;
    diag("Module $module not installed; $@");
}
use charnames qw(:full);

BEGIN {
    use_ok('DBI');
}

my $trace_file;
if ($DBD_PO_Test_Defaults::TRACE) {
    open $trace_file, '>', DBD_PO_Test_Defaults::trace_file_name();
}

# build table
sub build_table {
    my $param = {charset => shift};

    my $charset = $param->{charset};
    my $dbh = $param->{dbh} = DBI->connect(
        "dbi:PO:f_dir=$DBD_PO_Test_Defaults::PATH;charset=$charset",
        undef,
        undef,
        {
            RaiseError => 1,
            PrintError => 0,
            AutoCommit => 1,
        },
    );
    isa_ok($dbh, 'DBI::db', "connect ($charset)");

    if ($trace_file) {
        $dbh->trace(4, $trace_file);
    }

    @{$param}{qw(table table_file)} = (
        $DBD_PO_Test_Defaults::TABLE_13,
        $DBD_PO_Test_Defaults::FILE_13,
    );
    for my $name (@{$param}{qw(table table_file)}) {
        $name =~ s{\?}{$charset}xms;
    }

    my $result = $dbh->do(<<"EO_SQL");
        CREATE TABLE $param->{table} (
            msgid VARCHAR,
            msgstr VARCHAR
        )
EO_SQL
    is($result, '0E0', "create table ($charset)");
    ok(-e $param->{table_file}, "table file found ($charset)");

    return $param;
}

sub add_header {
    my $param = shift;

    my $dbh = $param->{dbh};
    my $msgstr = $dbh->func(
        undef,
        'build_header_msgstr',
    );
    my $result = $dbh->do(<<"EO_SQL", undef, $msgstr);
        INSERT INTO $param->{table} (
            msgstr
        ) VALUES (?)
EO_SQL
    is($result, 1, "add header ($param->{charset})");

    return $param;
}

sub add_line {
    my $param = shift;

    my $msgid  = "id_\N{SECTION SIGN}";
    my $msgstr = "str_\N{SECTION SIGN}";
    my $result = $param->{dbh}->do(<<"EO_SQL", undef, $msgid, $msgstr);
        INSERT INTO $param->{table} (
            msgid,
            msgstr
        ) VALUES (?, ?)
EO_SQL
    is($result, 1, "add line ($param->{charset})");

    return $param;
}

sub check_table_file {
    my $param = shift;

    my $po = <<"EOT";
msgid ""
msgstr ""
"MIME-Version: 1.0\\n"
"Content-Type: text/plain; charset=$param->{charset}\\n"
"Content-Transfer-Encoding: 8bit"

msgid "id_\N{SECTION SIGN}"
msgstr "str_\N{SECTION SIGN}"

EOT
    local $/ = ();
    open my $file1, "< :encoding($param->{charset})", $param->{table_file} or die $!;
    my $content1 = <$file1>;
    open my $file2, "< :encoding($param->{charset})", \($po) or die $!;
    my $content2 = <$file2>;
    eq_or_diff($content1, $content2, "check po file ($param->{charset})");

    return $param;
}

sub drop_table {
    my $param = shift;

    my $result = $param->{dbh}->do(<<"EO_SQL");
        DROP TABLE $param->{table}
EO_SQL
    is($result, '-1', 'drop table');
    ok(! -e $param->{table_file}, "drop table ($param->{charset})");

    return $param;
}

() = map {
         drop_table($_);
     }
     map {
         check_table_file($_);
     }
     map {
         add_line($_);
     }
     map {
         add_header($_);
     }
     map {
         build_table($_);
     } qw(utf-8 ISO-8859-1);