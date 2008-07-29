#!perl -T

use strict;
use warnings;

use Test::DBD::PO::Defaults;
use Test::More tests => 18;
eval {
    use Test::Differences;
};
if ($@) {
    *eq_or_diff = \&is;
    diag('Module Test::Differences not installed');
}

BEGIN {
    require_ok('DBI');
    require_ok('charnames');
    charnames->import(':full');
}

my $trace_file;
if ($Test::DBD::PO::Defaults::TRACE) {
    open $trace_file, '>', Test::DBD::PO::Defaults::trace_file_name();
}

# build table
sub build_table {
    my $param = {charset => shift};

    my $charset = $param->{charset};
    my $dbh = $param->{dbh} = DBI->connect(
        "dbi:PO:f_dir=$Test::DBD::PO::Defaults::PATH;po_eol=\n;charset=$charset",
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
        $Test::DBD::PO::Defaults::TABLE_13,
        $Test::DBD::PO::Defaults::FILE_13,
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

    SKIP:
    {
        skip('drop table', 2)
            if ! $Test::DBD::PO::Defaults::DROP_TABLE;

        my $result = $param->{dbh}->do(<<"EO_SQL");
            DROP TABLE $param->{table}
EO_SQL
        is($result, '-1', 'drop table');
        ok(! -e $param->{table_file}, "drop table ($param->{charset})");
    }

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
