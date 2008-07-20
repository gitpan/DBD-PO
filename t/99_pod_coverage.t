#!perl -T

use strict;
use warnings;

use Test::More;

my ($module, $version) = qw(Test::Pod::Coverage 1.04);
eval "use $module $version";
plan skip_all => "$module $version required for testing POD coverage" if $@;
all_pod_coverage_ok();
