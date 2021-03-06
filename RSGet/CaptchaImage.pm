package RSGet::CaptchaImage;
# This file is an integral part of rsget.pl downloader.
#
# 2009-2010 (c) Przemysław Iskra <sparky@pld-linux.org>
#		This program is free software,
# you may distribute it under GPL v2 or newer.

use strict;
use warnings;
use RSGet::Tools;
set_rev qq$Id$;

# new from file data
sub new # {{{
{
	my $class = shift;
	my $imgdata = shift;

	require GD;
	GD::Image->trueColor( 1 );
	my $img = GD::Image->new( $$imgdata );
	die "Cannot decode image data, either it is garbage or " .
		"your GD library does not support this format\n" unless $img;

	my $w = $img->width;
	my $h = $img->height;

	my @data;
	for ( my $y = 0; $y < $h; $y++ ) {
		my @line;
		for ( my $x = 0; $x < $w; $x++ ) {
			my $ci = $img->getPixel( $x, $y );
			my @rgb = $img->rgb( $ci );
			push @line, \@rgb;
		}
		push @data, \@line;
	}

	my $self = {
		w => $w,
		h => $h,
		data => \@data,
	};

	bless $self, $class;
} # }}}

# new white image
sub newWhite # {{{
{
	my $class = shift;
	my $w = shift;
	my $h = shift;

	my @data;
	for ( my $y = 0; $y < $h; $y++ ) {
		my @line = map { 0xff } (1..$w);
		push @data, \@line;
	}
	
	my $self = {
		w => $w,
		h => $h,
		data => \@data,
	};

	bless $self, $class;
} # }}}

# write bitmap file
sub write_bmp # {{{
{
	my $self = shift;
	my $name = shift;

	my $wlen = $self->{w} * 3 + 3;
	$wlen &= ~3;
	my $size = $wlen * $self->{h};

	my $line_pad = "\0" x ( $wlen - $self->{w} * 3 );

	my @lines;
	for ( my $y = $self->{h} - 1; $y >= 0; $y-- ) {
		my $iline = $self->{data}->[$y];
		my @oline;
		foreach my $pix ( @$iline ) {
			my @pix;
			if ( ref $pix ) {
				@pix = map { $_ < 0 ? 0 : $_ > 255 ? 255 : int $_ } @$pix[ (2, 1, 0) ];
			} else {
				my $p = $pix < 0 ? 0 : $pix > 255 ? 255 : int $pix;
				@pix = ( $p, $p, $p );
			}
			push @oline, pack "CCC", @pix;
		}
		push @lines, join "", @oline, $line_pad;
	}

	my @header = ( 66, 77, 54 + $size, 0, 54, 40,
		$self->{w}, $self->{h}, 1, 24, 0, $size, 2835, 2835, 0, 0 );

	my $header = pack "CCVVVVVVvvVVVVVV", @header;

	open F_OUT, ">", $name;
	binmode F_OUT;
	print F_OUT $header;
	print F_OUT join "", @lines;
	close F_OUT;
} # }}}

# $code should return luma (greyscale) value
sub color_filter # {{{
{
	my $self = shift;
	my $code = shift;

	my $data = $self->{data};
	foreach my $line ( @$data ) {
		foreach my $pixel ( @$line ) {
			$pixel = &$code( @$pixel );
		}
	}
} # }}}

# call $code for each pixel
sub pix_filter # {{{
{
	my $self = shift;
	my $code = shift;

	my $w = $self->{w};
	my $h = $self->{h};
	for ( my $y = 0; $y < $h; $y++ ) {
		for ( my $x = 0; $x < $w; $x++ ) {
			my $pix = $self->pix( $x, $y );
			&$code( $pix );
		}
	}
} # }}}

# bring $min..$max values to 0..255 interval
sub luma_emphasize # {{{
{
	my $self = shift;
	my $min = shift;
	my $max = shift;
	my $mult = 256 / ( $max - $min );

	my $data = $self->{data};
	foreach my $line ( @$data ) {
		foreach ( @$line ) {
			$_ = ( $_ - $min ) * $mult;
		}
	}
} # }}}

# clip luma to 0..255 values
sub luma_clip # {{{
{
	my $self = shift;

	my $data = $self->{data};
	foreach my $line ( @$data ) {
		foreach ( @$line ) {
			$_ = $_ > 255 ? 255 : $_ < 0 ? 0 : $_;
		}
	}
} # }}}

# exponential to linear
sub luma_degamma # {{{
{
	my $self = shift;
	my $gamma = shift;

	my $data = $self->{data};
	foreach my $line ( @$data ) {
		foreach ( @$line ) {
			$_ = ($_ / 255) ** $gamma * 255;
		}
	}
} # }}}

# linear to exponential
sub luma_togamma # {{{
{
	my $self = shift;
	return $self->luma_degamma( 1 / shift );
} # }}}

sub histogram # {{{
{
	my $self = shift;

	my @h = map { 0 } (0..255);
	my $data = $self->{data};
	foreach my $line ( @$data ) {
		foreach ( @$line ) {
			my $v = $_ < 0 ? 0 : $_ > 255 ? 255 : int $_;
			$h[ $v ]++;
		}
	}

	return \@h;
} # }}}

# set border pixels to some color
sub set_border # {{{
{
	my $self = shift;
	my $color = shift;

	$self->set_lines( $color, 0, $self->{h} - 1 );
	$self->set_columns( $color, 0, $self->{w} - 1 );
} # }}}

sub set_lines # {{{
{
	my $self = shift;
	my $color = shift;
	my @select = @_;

	my $data = $self->{data};
	foreach my $i ( @select ) {
		my $line = $data->[ $i ];
		foreach ( @$line ) {
			$_ = $color;
		}
	}
} # }}}
sub set_columns # {{{
{
	my $self = shift;
	my $color = shift;
	my @select = @_;

	my $data = $self->{data};
	foreach my $line ( @$data ) {
		foreach my $i ( @select ) {
			$line->[ $i ] = $color;
		}
	}
} # }}}

# chop image into pieces
sub chop # {{{
{
	my $self = shift;

	my @left = (0, @_);
	my @right = (@_, $self->{w});

	my @parts;
	for ( my $i = 0; $i < scalar @right; $i++ ) {
		push @parts, $self->crop( x1 => $left[ $i ], x2 => $right[ $i ] - 1 );
	}
	return @parts;
} # }}}

# call ocr program
sub ocr # {{{
{
	my $self = shift;

	my $file = "cap_" . randid();
	my $bmp = "$file.bmp";
	my $txt = "$file.txt";

	unlink $bmp, $txt;
	$self->write_bmp( $bmp );
	
	my $tes = `tesseract $bmp $file 2>&1`;
	chomp $tes;
	if ( $tes ne "Tesseract Open Source OCR Engine" ) {
		warn "tesseract failed; check your instalation!\n";
		warn "tesseract: $tes" if $tes;
	}
	
	my $text;
	if ( open my $f_in, "<", $txt ) {
		$text = <$f_in>;
		close $f_in;
	}
	unlink $bmp, $txt;

	return "" unless $text;
	chomp $text;
	return $text;
} # }}}

# cut part of an image
sub crop # {{{
{
	my $src = shift;
	my %o = @_;

	$o{x1} = 0 if not defined $o{x1} and not defined $o{x2};
	$o{y1} = 0 if not defined $o{y1} and not defined $o{y2};
	if ( defined $o{w} ) {
		if ( not defined $o{x2} ) {
			$o{x2} = $o{x1} + $o{w};
		} elsif ( not defined $o{x1} ) {
			$o{x1} = $o{x2} - $o{w};
		}
	}
	if ( defined $o{h} ) {
		if ( not defined $o{y2} ) {
			$o{y2} = $o{y1} + $o{h};
		} elsif ( not defined $o{y1} ) {
			$o{y1} = $o{y2} - $o{h};
		}
	}
	$o{x1} = 0 if not defined $o{x1} or $o{x1} < 0;
	$o{y1} = 0 if not defined $o{y1} or $o{y1} < 0;
	my $maxx = $src->{w} - 1;
	$o{x2} = $maxx if not defined $o{x2} or $o{x2} > $maxx;
	my $maxy = $src->{h} - 1;
	$o{y2} = $maxy if not defined $o{y2} or $o{y2} > $maxy;
	return undef if $o{x1} > $o{x2};
	return undef if $o{y1} > $o{y2};

	my $src_pix = $src->{data};
	my @pix;
	for ( my $y = $o{y1}; $y <= $o{y2}; $y++ ) {
		my @line;
		for ( my $x = $o{x1}; $x <= $o{x2}; $x++ ) {
			my $pix = $src_pix->[ $y ]->[ $x ];
			# XXX copy if ref
			push @line, $pix;
		}
		push @pix, \@line;
	}

	my $w = $o{x2} - $o{x1} + 1;
	my $h = $o{y2} - $o{y1} + 1;

	my $self = {
		w => $w,
		h => $h,
		data => \@pix,
	};

	bless $self, "RSGet::CaptchaImage";
} # }}}

sub doublesize # {{{
{
	my $src = shift;
	my $w = $src->{w};
	my $h = $src->{h};

	my $src_pix = $src->{data};
	my @data;
	foreach my $line ( @$src_pix ) {
		my @line;
		foreach my $pix ( @$line ) {
			push @line, $pix, $pix;
		}
		push @data, \@line;
		push @data, \@line;
	}

	my $self = {
		w => $w * 2,
		h => $h * 2,
		data => \@data,
	};

	bless $self, "RSGet::CaptchaImage";
} # }}}

sub pix # {{{
{
	my $self = shift;
	my $x = shift;
	my $y = shift;

	return RSGet::CaptchaImage::Pixel->new( $self, $x, $y );
} # }}}

package RSGet::CaptchaImage::Pixel;

sub up # {{{
{
	my $self = shift;
	return $self->{img}->pix( $self->{x}, $self->{y} - 1 );
} # }}}
sub down # {{{
{
	my $self = shift;
	return $self->{img}->pix( $self->{x}, $self->{y} + 1 );
} # }}}
sub left # {{{
{
	my $self = shift;
	return $self->{img}->pix( $self->{x} - 1, $self->{y} );
} # }}}
sub right # {{{
{
	my $self = shift;
	return $self->{img}->pix( $self->{x} + 1, $self->{y} );
} # }}}

sub get # {{{
{
	my $self = shift;
	my $pixel = $self->{img}->{data}->[ $self->{y} ]->[ $self->{x} ];
	if ( wantarray ) {
		if ( ref $pixel ) {
			return @$pixel;
		} else {
			return ( $pixel, $pixel, $pixel );
		}
	} else {
		if ( ref $pixel ) {
			my $sum = 0;
			my @mult = ( 0.30, 0.59, 0.11 );
	
			foreach my $i ( (0..2) ) {
				$sum += $pixel->[ $i ] * $mult[ $i ];
			}
			return $sum;
		} else {
			return $pixel;
		}
	}
} # }}}
sub set # {{{
{
	my $self = shift;
	my $pixel;
	if ( scalar @_ >= 3 ) {
		$pixel = [ @_[0..2] ];
	} else {
		$pixel = shift;
	}
	$self->{img}->{data}->[ $self->{y} ]->[ $self->{x} ] = $pixel;
} # }}}

sub isBelow # {{{
{
	my $self = shift;
	if ( scalar @_ >= 3 ) {
		my @max = @_[0..2];
		my @value = $self->get();
		foreach my $i ( (0..2) ) {
			return 0 if $value[ $i ] >= $max[ $i ];
		}
		return 1;
	} else {
		my $max = shift;
		my $value = $self->get();
		return $value < $max;
	}
} # }}}
sub isAbove # {{{
{
	my $self = shift;
	if ( scalar @_ >= 3 ) {
		my @min = @_[0..2];
		my @value = $self->get();
		foreach my $i ( (0..2) ) {
			return 0 if $value[ $i ] <= $min[ $i ];
		}
		return 1;
	} else {
		my $min = shift;
		my $value = $self->get();
		return $value > $min;
	}
} # }}}

sub new # {{{
{
	my $class = shift;
	my $img = shift;
	my $x = shift;
	my $y = shift;

	return undef unless $x >= 0;
	return undef unless $y >= 0;
	return undef unless $x < $img->{w};
	return undef unless $y < $img->{h};

	my $self = {
		img => $img,
		x => $x,
		y => $y,
	};
	bless $self, $class;
	return $self;
} # }}}

1;

# vim: ts=4:sw=4:fdm=marker
