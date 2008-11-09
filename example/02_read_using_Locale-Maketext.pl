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
                || q{.};
    my $table = $TABLE_2X
                || 'table_xx.po'; # for langueage xx

    Locale::Maketext::Lexicon->import({
        xx      => [
            Gettext => "$path/$table",
        ],
        _decode => 1, # unicode mode
    });
}

use strict;
use warnings;

use Carp qw(croak);
use Tie::Sub ();

my $lh = Example::L10N->get_handle('xx') or croak 'What language';
# tie for interpolation in strings
# $lh{1}      will be the same like $lh->maketext(1)
# $lh{[1, 2]} will be the same like $lh->maketext(1, 2)
tie my %lh, 'Tie::Sub', sub { return $lh->maketext(@_) };

print <<"EOT";
$lh{'text1 original'}

$lh{"text2 original\n2nd line of text2"}

$lh{['text3 original [_1]', 'is good']}

$lh{['text4 original [quant,_1,o_one,o_more,o_nothing]', 0]}
$lh{['text4 original [quant,_1,o_one,o_more,o_nothing]', 1]}
$lh{['text4 original [quant,_1,o_one,o_more,o_nothing]', 2]}
EOT
;