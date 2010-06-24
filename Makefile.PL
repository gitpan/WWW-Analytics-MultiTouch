use strict;
use warnings;
use ExtUtils::MakeMaker;

WriteMakefile(
    NAME                => 'WWW::Analytics::MultiTouch',
    AUTHOR              => 'Jon Schutz <jon at jschutz.net>',
    VERSION_FROM        => 'lib/WWW/Analytics/MultiTouch.pm',
    ABSTRACT_FROM       => 'lib/WWW/Analytics/MultiTouch.pm',
    ($ExtUtils::MakeMaker::VERSION >= 6.3002
      ? ('LICENSE'=> 'perl')
      : ()),
    PL_FILES            => {},
    PREREQ_PM => {
        'Test::More' => 0,
	'Net::Google::Analytics' => 0,
	'Net::Google::AuthSub' => 0,
	'DateTime' => 0,
	'DateTime::Duration' => 0,
	'Params::Validate' => 0,
	'Data::Dumper' => 0,
	'List::Util' => 0,
	'Pod::Usage' => 0,
	'Getopt::Long' => 0,

    },
    dist                => { COMPRESS => 'gzip -9f', SUFFIX => 'gz', },
    clean               => { FILES => 'WWW-Analytics-MultiTouch-*' },
);
