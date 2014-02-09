package Graphics::DZI::Hash::viaFileSystem;

use strict;
use warnings;
use Data::Dumper;

require Tie::Hash;
our @ISA = qw(Tie::StdHash);

=pod

=head1 NAME

Graphics::DZI::Hash::viaFileSystem - Hash based storage for tiles

=head1 SYNOPSIS

@@@

=cut

sub TIEHASH  {
    my $class = shift;
    my %options = @_;
    $Graphics::DZI::log->logdie ("no root directory specified") unless $options{root};
    $Graphics::DZI::log->logdie ("no prefix specified")         unless defined $options{prefix};

    $options{'files_directory'} = $options{root} . $options{prefix} . '_files/';
    use File::Path qw(make_path);
    make_path ($options{'files_directory'});
    
    return bless [{}, \%options], $class;
}

sub STORE {
    my $self  = shift;
    my $key   = shift;   # only the tid
    my $value = shift;   # a complete HASH with MIME => value entries

    my $level;
    $key =~ qr{^(\d+)} and $level = $1;
    make_path ($self->[1]->{'files_directory'} . $level);

#warn "STORE $key => ". (Dumper [ caller ]). Dumper $value;
    my $filename = $self->[1]->{'files_directory'} . $key;
#warn "storing to '$filename'";
    open (my $fh, '>', $filename)
	or $Graphics::DZI::log->logdie ("cannot open for writing $filename ($!)");  # that is really bad, we stop here
    print $fh $value;
    close $fh;
}

sub FETCH {
    my $self = shift;
    my $key  = shift;

#warn "FETCH $key". Dumper [ caller ];
    my $filename = $self->[1]->{'files_directory'} . $key;
#warn "fetch from  $filename";
    open (my $fh, '<', $filename) 
	or return undef;              # if we cannot find a file, well report that in HASH-speak
    use Perl6::Slurp;
    my $c = slurp $fh;
    close $fh;
    return $c;
}

sub FIRSTKEY {
    my $self = shift;

    my $dir = $self->[1]->{'files_directory'};
    my $pattern = "${dir}*/*.png";
    $self->[2] = { map { $_ =~ qr{(\d+/\d+_\d+\.png)} && $1 => undef  }
                   glob ($pattern) };
#warn "FIRSTKEY ".Dumper $self->[2];
    return each %{ $self->[2] };
}

sub NEXTKEY {
    my $self = shift;
    return each %{ $self->[2] }
}

sub DELETE {
    my $self = shift;
    my $key  = shift;

#warn "DELETE $key". Dumper [ caller ];
    my $filename = $self->[1]->{'files_directory'} . $key;
    open (my $fh, '<', $filename) 
	or return undef;              # if we cannot find a file, well report that in HASH-speak
    use Perl6::Slurp;
    my $c = slurp $fh;
    close $fh;
#warn "unlinking $filename";
    unlink $filename;
    return $c;
}

sub EXISTS {
    my $self = shift;
    my $key  = shift;

    my $filename = $self->[1]->{'files_directory'} . $key;
    return -e $filename;
}

sub CLEAR {
    my $self = shift;
    use File::Path;
    rmtree ( $self->[1]->{root} );
    mkdir  ( $self->[1]->{root} );
}

our $VERSION = '0.01';

1;

__END__


use MIME::Types;
my $mimetypes = MIME::Types->new; # our database

sub _flatten {
    my $s = shift;
    return unless $s;

    my $mime = shift;
    if ($mime) {
	if (my $def = $mimetypes->type ($mime)) { # we know about an extension
	    my ($ext) = $def->extensions;
#warn "$mime => ext $ext";
	    $s = "${s}.${ext}" unless $s =~ /\.$ext/;   # add the extension unless we already got it
	} else {
	    $s = "${s}_${mime}";
	}
    } else {  # else mime undef => we add wildcard
	$s = "${s}*";
    }
    $s =~ s{/}{_}g; # generic replacement

    return $s;
}

sub _load_meta {
    my $filename = shift;
    use Perl6::Slurp;
    open (my $fh, '<', $filename) or return ();
    my %meta = map { /(.+?)\s*:\s*(.*)/ and ($1 => $2) }
               slurp $fh, {chomp=>1};
#warn "load meta $filename  ".Dumper \%meta;
    close $fh;
    return %meta;
}

sub _save_meta {
    my $filename = shift;
    my $value    = shift;
#warn "save meta $filename value is ".Dumper $value;
    open (my $fh, '>', $filename) or $TM2::log->logdie ("cannot open for writing $filename ($!)");
    print $fh $value->headers_as_string ("\n");
    close $fh;
}

sub _load_content {
    my $filename = shift;
#warn "load content $filename".Dumper [ caller ];
    open (my $fh, '<', $filename) or $TM2::log->logdie ("cannot read $filename");
    my $c = slurp $fh;
    close $fh;
    return $c;
}

sub _save_content {
    my $filename = shift;
    my $value    = shift;
#warn "save data $filename value is ".Dumper $value;
    open (my $fh, '>', $filename) or $TM2::log->logdie ("cannot open for writing $filename ($!)");
    print $fh $value->content;
    close $fh;
}

