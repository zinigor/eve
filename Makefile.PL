use 5.006;
use strict;
use warnings;
use ExtUtils::MakeMaker;

WriteMakefile(
    NAME                => 'Eve',
    AUTHOR              => q{Igor Zinovyev <zinigor@gmail.com>},
    VERSION_FROM        => 'lib/Eve.pm',
    ABSTRACT_FROM       => 'lib/Eve.pm',
    ($ExtUtils::MakeMaker::VERSION >= 6.3002
      ? ('LICENSE'=> 'perl')
      : ()),
    PL_FILES            => {},
    PREREQ_PM => {
        'Test::More' => 0,
    },
    dist                => { COMPRESS => 'gzip -9f', SUFFIX => 'gz', },
    clean               => { FILES => 'Eve-*' },
);
