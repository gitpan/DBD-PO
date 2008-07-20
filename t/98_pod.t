#!perl -T

use strict;
use warnings;

use Test::More;

my ($module, $version) = qw(Test::Pod 1.14);
eval "use $module $version";
plan skip_all => "$module $version required for testing POD" if $@;
all_pod_files_ok();
