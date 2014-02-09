use strict;
use warnings;

use Test::More 'no_plan';
use Data::Dumper;
use Test::Exception;


BEGIN { use_ok 'Graphics::DZI' }

use constant DONE => 1;

if (DONE) {
    throws_ok {
	my $dzi = new Graphics::DZI (image => 23,
				     overlap  => 4,
				     tilesize => 128,
	    );
    } qr/Validation failed/i, 'invalid image';

    use Image::Magick;
    my $image = Image::Magick->new (size=> "100x50");
    $image->Read('xc:white');
    my $dzi = new Graphics::DZI (image => $image,
				 overlap  => 4,
				 tilesize => 128,
	);

    isa_ok ($dzi, 'Graphics::DZI');

    like ($dzi->descriptor, qr/xml/,         'XML descriptor exists');
    like ($dzi->descriptor, qr/Width='100'/, 'XML descriptor width');
    like ($dzi->descriptor, qr/Height='50'/, 'XML descriptor height');

    is ($dzi->tilesize, 128, 'tilesize echo');
    is ($dzi->overlap,    4, 'overlap echo');
}

if (DONE) {
    use Image::Magick;
    my $image = Image::Magick->new (size=> "100x50");
    $image->Read('xc:white');
    use Graphics::DZI::Files;
    my $dzi = new Graphics::DZI::Files (image => $image,
					prefix => 'xxx',
					path   => '/tmp/',
	);

    isa_ok ($dzi, 'Graphics::DZI');
    is ($dzi->path,    '/tmp/', 'path echo');
# TODO: iterate & check whether all is there
}

if (DONE) {

    {
	use Image::Magick;
	my $image = Image::Magick->new (size=> "600x400");
	$image->Read('xc:white');

	my $h = {};
	use Graphics::DZI::Hash;
	my $dzi = new Graphics::DZI::Hash (image => $image,
#					   tilesize => 256,
					   hash  => $h);
	isa_ok ($dzi, 'Graphics::DZI');
	
	$dzi->iterate;

	map { like ($_, qr{\d+/\d+_\d+\.png}, 'hash key, in-memory hash' )} keys %$h;

	foreach my $t (values %$h) {
	    my $img = Image::Magick->new (magick=>'png');
	    $img->BlobToImage( $t );
	    ok ( $img->Get ('width')  <= ($dzi->tilesize + 2*$dzi->overlap), 'tile dimensions');
	    ok ( $img->Get ('height') <= ($dzi->tilesize + 2*$dzi->overlap), 'tile dimensions');
	}
	
#    warn Dumper [ keys %$h ];
    }

    {
	use Image::Magick;
	my $image = Image::Magick->new (size=> "600x400");
	$image->Read('xc:white');

	use File::Path qw(remove_tree);
	remove_tree('/tmp/dzi/');

	use Graphics::DZI::Hash::viaFileSystem;
	my %h = ();
	tie %h, 'Graphics::DZI::Hash::viaFileSystem', root => '/tmp/dzi/', prefix => 'xxx';

	use Graphics::DZI::Hash;
	my $dzi = new Graphics::DZI::Hash (image => $image,
					   hash  => \%h);
	isa_ok ($dzi, 'Graphics::DZI');
	
	$dzi->iterate;

	ok (-r '/tmp/dzi/xxx_files/0/0_0.png', 'level 0 PNG');
	ok (-r '/tmp/dzi/xxx_files/10/0_0.png', 'level 10 PNG');

	map { like ($_, qr{\d+/\d+_\d+\.png}, 'hash key, tied to file system' )} keys %h;

	foreach my $t (values %h) {
	    my $img = Image::Magick->new (magick=>'png');
	    $img->BlobToImage( $t );
	    ok ( $img->Get ('width')  <= ($dzi->tilesize + 2*$dzi->overlap), 'tile dimensions');
	    ok ( $img->Get ('height') <= ($dzi->tilesize + 2*$dzi->overlap), 'tile dimensions');
	}

	my $i = delete $h{'10/0_0.png'};
#	warn $i;
	ok ($i, 'deleted received');

	ok (! exists $h{'10/0_0.png'}, 'deleted one tile');
	
    }

}

__END__
