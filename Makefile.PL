use ExtUtils::MakeMaker;
# See lib/ExtUtils/MakeMaker.pm for details of how to influence
# the contents of the Makefile that is written.

WriteMakefile(
    'NAME'         => 'WWW::IstanbulTeknik',
    'VERSION_FROM' => 'lib/WWW/IstanbulTeknik.pm',
    'PREREQ_PM'    => {
                       'LWP'                      => '5.76',
                       'WWW::Mechanize'           => '1.02',
                       'HTML::TableContentParser' => '0.13',
    },
    ($] >= 5.005 ? (
    'AUTHOR'       => 'Burak Gursoy <burak@cpan.org>',
    'ABSTRACT'     => 'Programmer interface to Istanbul Technical University',
     ) : ()),
);
