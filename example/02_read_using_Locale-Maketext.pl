#!perl

# Lexicon
{
    package Example::L10N;

    use strict;
    use warnings;

    use parent qw(Locale::Maketext);
    use Locale::Maketext::Lexicon;

    # for test examples only
    our $PATH;
    our $TABLE_2X;
    eval 'use Test::DBD::PO::Defaults qw($PATH $TABLE_2X)';

    my $path  = $PATH
                || '.';
    my $table = $TABLE_2X
                || 'table.po';

    Locale::Maketext::Lexicon->import({
        en      => [
            Gettext => "$path/$table",
        ],
        _decode => 1,
    });
}

use strict;
use warnings;

use Carp qw(croak);
use Data::Dumper ();

my $lh = Example::L10N->get_handle('en') or croak 'What language';

my @output = map {
    ref $_
    ? ( $_->[0] => $lh->maketext( @{$_} ) )
    : ( $_      => $lh->maketext($_)      );
} (
    'text original',
    "text original\n2nd line of text2",
    [ 'text original [_1]', 'is good' ],
    [ 'original [quant,_1,o_one,o_more,o_nothing]', 0],
    [ 'original [quant,_1,o_one,o_more,o_nothing]', 1],
    [ 'original [quant,_1,o_one,o_more,o_nothing]', 2],
);

print Data::Dumper->new([\@output], [qw(output)])
                  ->Quotekeys(0)
                  ->Useqq(1)
                  ->Dump();