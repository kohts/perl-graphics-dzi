package Graphics::DZI::Document;

use strict;
use warnings;

=head1 NAME

Graphics::DZI::Document - DeepZoom Image Pyramid, Sparse Document Images

=head1 SYNOPSIS

    # prepare a bunch of Image::Magick objects
    @pages = ......;

    # create the overlay itself
    use Graphics::DZI::Document;
    my $o = new Graphics::DZI::Document (pages => \@pages,
					 x => 80000, 'y' => 40000,
					 pack => 'linear',
					 squeeze => 256);

    # use the Graphics::DZI::Files and add this as overlay

=head1 DESCRIPTION

This subclass of L<Graphics::DZI::Overlay> handles documents as overlays for extremely sparse
DeepZoom images. Documents here are also images, but not a single one, but one for each document
page.

What is also different from a normal overlay image is that document overlays will show a different
number of images, depending on the zoom level. First, when the canvas is the dominant feature, only
a small first page is show. Whenever that first page is fairly readable, the first 4 pages are shown
in the slot. Then the next 9 or 16, depending on whether the growth is C<linear> or C<exponential>.

=cut

use Moose;
extends 'Graphics::DZI::Overlay';

=head1 INTERFACE

=head2 Constructor

Different to the superclass not the image, but a sequence of pages have to be passed in. Optionally,
a parameter C<pack> determines between C<linear> and C<exponential> growth of pages at higher
resolutions. With linear you actually get 1, 4, 9, 16, 25...  documents (so it is actually squared
linear). With exponential you get more aggressively 1, 4, 16, 32, ... pages.

Since 0.06: Individual pages cannot be only single images (as so far), but now also multiple images
(Image::Magick allows you to hold multiple images in one object). The list of image objects will be
flattened.

Since 0.06: Accepts a field C<formatting> with possible values C<portrait> (default) and
C<landscape>.  In the latter mode, the first half page is show, at deeper levels then 2 pages
side-by-side, then 8 pages, then 64, if there are that many. B<NOTE>: Setting the format to landscape
implies also C<pack> to be C<exponential>.

=cut

use Moose::Util::TypeConstraints qw(enum);

has 'pages'     => (isa => 'ArrayRef',       is => 'rw', required => 1);
has '+image'    => (isa => 'Image::Magick',              required => 0);
has 'W'         => (isa => 'Int'   ,        is => 'rw');
has 'H'         => (isa => 'Int'   ,        is => 'rw');
has 'sqrt'      => (isa => 'Num',           is => 'rw');

enum 'packing'    => qw( exponential linear );
has 'pack'        => (isa => 'packing',       is => 'rw', default => 'exponential');

enum 'formatting' => qw( portrait landscape );
has 'format'      => (isa => 'formatting',    is => 'rw', default => 'portrait');

sub BUILD {
    my $self = shift;
    {
	my @pages = map { (@$_)[0..$#$_] } @{ $self->pages };                            # flatten multiple images in one Image::Magick object
	$self->pages (\@pages);                                                          # OO programming is soooo elegant. really.
    }

    ($self->{W}, $self->{H}) = $self->pages->[0]->GetAttributes ('width', 'height');     # get dimensions from the first document, assume others to be the same

    $self->pack ('exponential') if $self->format eq 'landscape';

    use feature "switch";
    given ($self->{pack}) {
	when ('linear')      {
	    use POSIX;
	    $self->{ sqrt } = POSIX::ceil ( sqrt ( scalar @{$self->pages}) );     # take the root + 1
	}
	when ('exponential') {
	    use POSIX;
	    my $log2 = POSIX::ceil (log (scalar @{$self->pages}) / log (2));      # next fitting 2-potenz
	    $log2++ if $log2 % 2;                                                 # we can only use even ones
	    $self->{ sqrt }  = ( 2**($log2/2) );                                  # how many along one edge when we organize them into a square?
	}
	default { $Graphics::DZI::log->logdie ("unhandled packing"); }
    }

    $self->{ image } = _list2huge ($self->sqrt, $self->format, $self->W, $self->H, @{ $self->pages });
    $self->{ image }->Display();
}

sub _list2huge {
    my $sqrt    = shift;
    my $format  = shift;
    my ($W, $H) = (shift, shift);

    my $dim = sprintf "%dx%d", 
              map { $_ * $sqrt }
              ($W, $format eq 'landscape' ? $H/2 : $H);                           # with landscape we only take upper half
    $Graphics::DZI::log->debug ("building composite document: DIM $dim ($sqrt)");
    use Image::Magick;
    my $huge = Image::Magick->new ($dim);
    $huge->Read ('xc:white');
    $huge->Transparent (color => 'white');

    my @pages = @_;
    foreach my $a (0 .. $sqrt*$sqrt - 1) {
	last unless $pages[$a];
	my ($j, $i) = ( int( $a / $sqrt)  , $a % $sqrt );
	$log->debug ("    index $a (x,y) = $i $j");

	$huge->Composite (image => $pages[$a],
			  x     => $i * $W,
			 'y'    => $j * $H,
			  compose => 'Over',
	    );
    }
    $huge->Display();
    return $huge;
}

=head2 Methods

=over

=item B<halfsize>

This will be called by the overall DZI algorithm whenever this overlay is to be size-reduced by 2.

=cut

sub halfsize {
    my $self = shift;

    my ($w, $h) = $self->image->GetAttributes ('width', 'height');                     # current dimensions
    if ($self->{ sqrt } > 1) {
	use feature "switch";
	given ($self->{pack}) {
	    when ('linear')      { $self->{ sqrt }--;    }                             # in linear packing we simply reduce the square root by one
	    when ('exponential') { $self->{ sqrt } /= 2; }
	    default {}
	}
	$self->{ image } = _list2huge ($self->sqrt,                                    # pack sqrt x sqrt A4s into one image
				       $self->format,
				       $self->W, $self->H,
				       @{ $self->pages });
    }
    $self->image->Resize (width => int($w/2), height => int($h/2));                    # half size
    $self->{x} /= 2;                                                                   # dont forget x, y 
    $self->{y} /= 2;
}

=back

=head1 AUTHOR

Robert Barta, C<< <drrho at cpan.org> >>

=head1 COPYRIGHT & LICENSE

Copyright 2010|3 Robert Barta, all rights reserved.

This program is free software; you can redistribute it and/or modify it under the same terms as Perl
itself.

=cut

our $VERSION = '0.02';

"against all odds";

__END__
