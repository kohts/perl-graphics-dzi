use strict;
use warnings;

use Data::Dumper;


use Module::Build;
my $class = Module::Build->subclass(
    class => "Module::Build::Uploader",
    code => <<'SUBCLASS' );

sub ACTION_upload {
    my $self = shift;
    my $v = $self->dist_version();
    $self->do_system(('cpan-upload', "Graphics-DZI-$v.tar.gz"));
}

sub DEBVERSION {
    return 7;
}

sub ACTION_debian {
    my $self = shift;

    $self->depends_on("disttest");

    my $version = $self->dist_version;
    my $debversion = $self->DEBVERSION;
    my $author     = 'rho@devc.at';  # TODO: get this from below
    $self->do_system(qq{   DEB_BUILD_OPTIONS=nocheck dh-make-perl --build --email '$author' --version=$version-$debversion Graphics-DZI-$version } );

}
sub ACTION_inject {
    my $self = shift;

    $self->depends_on("debian");

    my $version = $self->dist_version;
    my $debversion = $self->DEBVERSION;
    $self->do_system(qq{ scp libgraphics-dzi-perl_${version}-${debversion}_all.deb packages.devc.at:packages/ } );
    $self->do_system(qq{ ssh packages.devc.at reprepro -b /var/www/packages/data/squeeze includedeb squeeze packages/libgraphics-dzi-perl_${version}-${debversion}_all.deb });
}
SUBCLASS

my $builder = Module::Build::Uploader->new(
    module_name         => 'Graphics::DZI',
    license             => 'perl',
#    version             => $version,
    dist_author         => 'Robert Barta <drrho@cpan.org>',
    dist_version_from   => 'lib/Graphics/DZI.pm',
    configure_requires => { 'Module::Build' => 0.40 },
    test_requires => {
        'Test::More'          => 0,
	'Test::Exception'     => 0,
	'Test::Pod::Coverage' => 0,
    },
    requires => {
	'Moose'               => 0,
	'Image::Magick'       => 0,
	'File::Path'          => '2.07',
	'File::Slurp'         => 0,
	'File::Basename'      => 0,
	'Getopt::Long'        => 0,
	'Pod::Usage'          => 0,
	'Log::Log4perl'       => 0,
	'Image::Magick'       => 0,
	'List::MoreUtils'     => 0,
	'Perl6::Slurp'        => 0,
    },
    script_files       => [ 'script/deepzoom' ],
    add_to_cleanup     => [ 'Graphics-DZI-*' ],
##    create_makefile_pl => 'traditional',
);

$builder->create_build_script();

__END__

