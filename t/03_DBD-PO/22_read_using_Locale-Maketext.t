#!perl -T

use strict;
use warnings;

use Test::DBD::PO::Defaults qw(run_example $DROP_TABLE $FILE_2X $TABLE_2X);
use Test::More;

$ENV{TEST_EXAMPLE} or plan(
    skip_all => 'Set $ENV{TEST_EXAMPLE} to run this test.'
);

plan(tests => 1);

is(
    run_example('02_read_using_Locale-Maketext.pl'),
    q{},
    'run 02_read_using_Locale-Maketext.pl',
);