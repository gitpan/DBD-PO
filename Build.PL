use strict;
use warnings;

use Module::Build;

Module::Build->new(
    module_name        => 'DBD::PO',
    license            => 'perl',
    dist_abstract      => 'DBD::PO - DBI driver for PO files',
    dist_author        => 'Steffen Winkler <steffenw@cpan.org>',
    dist_version_from  => 'lib/DBD/PO.pm',
    requires           => {
        parent             => 0,
        DBI                => 0, # for DBD::File
        'Params::Validate' => 0,
        Readonly           => 0,
        # Carp             => 0, # perl dist
        # Socket           => 0, # perl dist
    },
    build_requires => {
        'Test::Simple'       => 0, # for Test::More
        # 'Test::Differences => 0, # optional (test output is more readable)
    },
    create_makefile_pl   => 'traditional',
    recursive_test_files => 1,
    add_to_cleanup       => [ qw(
        META.yml *.bak *.gz Makefile.PL *.po *.txt
    ) ],
)->create_build_script();