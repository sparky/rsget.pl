#!/usr/bin/perl
#
use strict;
use warnings;
use Image::Magick;

my @alph = qw(A B C D E F G H K M N P Q R S T U V W X Y Z);
my @noalph = qw(I J L O);

my %size = (
	A => 28,
	B => 22,
	C => 21,
	D => 27,
	E => 16,
	F => 16,
	G => 26,
	H => 26,
	K => 20,
	M => 38,
	N => 28,
	P => 21,
	Q => 30,
	R => 22,
	S => 18,
	T => 19,
	U => 26,
	V => 22,
	W => 40,
	X => 23,
	Y => 18,
	Z => 18,
);

my @db;

sub read_db()
{
	print "Reading char db\n";
	my $dbf = new Image::Magick;
	$dbf->Read( "db.png" );
	foreach my $pos ( 0..3 ) {
		my @list = @alph;
		@list = (1..9) if $pos == 3;

		my $height = 32;
		my $width = 40;
		my $left = $width * $pos;
		$width = 22 if $pos == 3;
		my $top = 0;
	
		my %db;
		foreach my $char ( @list ) {
			my $db = $dbf->Clone();
			$db->Crop( width => $width, height => $height, x => $left, y => $top );
			$db{$char} = $db;
			$top += 32;
		}
		push @db, \%db;
	}
}

read_db();

sub get_char
{
	my ($src, $db, $width, $x) = @_;

	my $img = $src->Clone();
	$img->Crop( width => $width, height => 32, x => $x, y => 0 );
	$img->Extent( width => $width, height => 32, x => 0, y => 0 );

	my $min = 1;
	my $min_char = undef;
	foreach my $n ( keys %$db ) {
		my $x = $img->Compare( image => $db->{$n} );
		my ($e, $em) = $img->Get( 'error', 'mean-error' );
		if ( $em < $min ) {
			$min = $em;
			$min_char = $n;
		}
	}
	return $min_char;
}

sub captcha
{
	my $file_name = shift;

	my $img = new Image::Magick;
	$img->Read( $file_name );
	my ($width, $height) = $img->Get( 'columns', 'rows' );

	my $bg = new Image::Magick;
	$bg->Set( size => $width."x32" );
	$bg->Read( "xc:white" );
	$bg->Composite( image => $img );

	my @cap;
	push @cap, get_char( $bg, $db[0], 40, 0 );
	push @cap, get_char( $bg, $db[1], 40, $size{$cap[0]} - 6 );
	push @cap, get_char( $bg, $db[2], 40, $width - 56 );
	push @cap, get_char( $bg, $db[3], 22, $width - 22 );

	return join "", @cap;
}

my $all = 0;
my $nok = 0;
foreach my $file ( glob "????*.gif" ) {
	my $c = captcha( $file );
	unless ( $file =~ /^$c/ ) {
		print "Captcha mismatch: $file <> $c\n";
		$nok++;
	}
	$all++;
}
printf "Failed $nok of $all (%g%%)\n", $nok * 100 / $all;
