package Graphics::DZI::Hash;

use warnings;
use strict;

use Moose;
extends 'Graphics::DZI';

=head1 NAME

Graphics::DZI::Hash - DeepZoom Image Pyramid Generation, Hash-based

=head1 SYNOPSIS

  my $h = {};   # here we will store the tiles
  use Graphics::DZI::Hash;
  my $dzi = new Graphics::DZI::Files (image    => $image,
				      overlap  => 4,
				      tilesize => 256,
				      scale    => 2,
 				      format   => 'png',
                                      hash     => $h);
  $dzi->iterate ();


=head1 DESCRIPTION

This subclass of L<Graphics::DZI> generates tiles and stores them inside a hash. The key is
the path of the tile, the value the tile itself.

=head1 INTERFACE

=head2 Constructor

Additional to the parent class L<Graphics::DZI>, the constructor takes the following fields:

=over

=item C<format> (default C<png>):

An image format (C<png>, C<jpg>, ...). Any format L<Image::Magick> understands will do.

=item C<hash>: (default none)

=back

=cut

#has 'format'   => (isa => 'Str'   ,        is => 'ro', default => 'png');
has 'hash'    => (isa => 'HashRef'   ,      is => 'ro');

=head2 Methods

=over

=item B<manifest>

This method writes any tile into the hash.

=cut

sub manifest {
    my $self  = shift;
    my $tile  = shift;
    my $level = shift;
    my $row   = shift;
    my $col   = shift;

    $Graphics::DZI::log->debug ("saving tile $row $col -> $level");

    my $key = $level . '/' . (sprintf "%s_%s", $col, $row ) . '.' . $self->format;

    use Image::Magick;
    $self->hash->{ $key } = $tile->ImageToBlob (magick=>'png');
}

=pod

=item B<source_out>

This method takes one URL as parameter and outputs the hash-based contents there. At the moment the
URL should be of the form:

   file:/what/ever/where.dzi

=cut

sub source_out { # aka store the thing somewhere
    my $self = shift;
    my $url  = shift;

    $Graphics::DZI::log->debug ("sourcing out to $url");
    unless ($url =~ qr{file:((.+)\.(dzi|xml))$}) {
	$Graphics::DZI::log->logdie ("expect the URL to be of the form file:/what/ever/where.dzi");
    } else {
	my $path    = $2 . "_files/";
	my $dzifile = $1;
	use File::Path qw(make_path);
	make_path ($path);

	use File::Slurp;

	my $h = $self->hash;
	foreach my $t (keys %$h) {
	    $t =~ qr{^(\d+)};                                           # we need the level
	    make_path ($path . $1);                                     # make directory first
	    write_file ($path . $t, $h->{$t});                          # then write the PNG to the file in there
	}  # TODO: optimize: generate directories first, then write files
	write_file ($dzifile, $self->descriptor);   # finally also generate the XML .dzi file
    }

}


=back

=head1 AUTHOR

Robert Barta, C<< <drrho at cpan.org> >>

=head1 COPYRIGHT & LICENSE

Copyright 2013 Robert Barta, all rights reserved.

This program is free software; you can redistribute it and/or modify it under the same terms as Perl
itself.

=cut

our $VERSION = '0.01';

"against all odds";
