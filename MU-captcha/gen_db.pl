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

my %avg_1;

foreach my $n ( @alph ) {

my $avg = new Image::Magick;

foreach my $file ( glob "$n???*.gif" ) {
	my $img = new Image::Magick;
	$img->Read( $file );
	my ($w, $h) = $img->Get( 'columns', 'rows' );

	$img->Crop( width => 40, height => 32, x => 0, y => 0 );
	$img->Extent( width => 40, height => 32, x => 0, y => 0 );

	my $bg = new Image::Magick;
	$bg->Set( size => '40x32' );
	$bg->Read( "xc:white" );
	$bg->Composite( image => $img );

	push @$avg, @$bg;
}

my $p = $avg->Average();
$p->Write("avg_1_$n.png");
print "Wrote avg_1_$n.png\n";

$avg_1{$n} = $p;
}

my $avg_1;
{
	my $avg = new Image::Magick;
	foreach ( sort keys %avg_1 ) {
		push @$avg, $avg_1{$_};
	}
	$avg_1 = $avg->Append(stack=>1);
	$avg_1->Write("avg_1_all.png");
}


my $ok = 0;
my $nok = 0;
foreach my $file ( glob "????*.gif" ) {
	my $img = new Image::Magick;
	$img->Read( $file );
	my ($w, $h) = $img->Get( 'columns', 'rows' );

	$img->Crop( width => 40, height => 32, x => 0, y => 0 );
	$img->Extent( width => 40, height => 32, x => 0, y => 0 );

	my $bg = new Image::Magick;
	$bg->Set( size => '40x32' );
	$bg->Read( "xc:white" );
	$bg->Composite( image => $img );


	my $min = 1;
	my $min_n = undef;
	foreach my $n ( keys %avg_1 ) {
		my $x = $bg->Compare( image => $avg_1{$n} );
		my ($e, $em) = $bg->Get( 'error', 'mean-error' );
		if ( $em < $min ) {
			$min = $em;
			$min_n = $n;
		}
		#print "X: $x, $n, $e, $em\n";
	}
	if ( $file =~ /^$min_n/ ) {
		$ok++;
	} else {
		print "$file mismatch: $min_n\n";
		$nok++;
	}

	#print "$file: $w x $h\n";
}

print "OK: $ok, NOK: $nok\n";







my %avg_2;

foreach my $n ( @alph ) {

my $avg = new Image::Magick;

foreach my $file ( glob "?$n??*.gif" ) {
	$file =~ /^(.)/;
	my $fl = $1;
	my $img = new Image::Magick;
	$img->Read( $file );
	my ($w, $h) = $img->Get( 'columns', 'rows' );

	$img->Crop( width => 40, height => 32, x => $size{$fl} - 6, y => 0 );
	$img->Extent( width => 40, height => 32, x => 0, y => 0 );

	my $bg = new Image::Magick;
	$bg->Set( size => '40x32' );
	$bg->Read( "xc:white" );
	$bg->Composite( image => $img );

	push @$avg, @$bg;
}

my $p = $avg->Average();
$p->Write("avg_2_$n.png");
print "Wrote avg_2_$n.png\n";

$avg_2{$n} = $p;
}

my $avg_2;
{
	my $avg = new Image::Magick;
	foreach ( sort keys %avg_2 ) {
		push @$avg, $avg_2{$_};
	}
	$avg_2 = $avg->Append(stack=>1);
	$avg_2->Write("avg_2_all.png");
}


$ok = 0;
$nok = 0;
foreach my $file ( glob "????*.gif" ) {
	$file =~ /^(.)/;
	my $fl = $1;

	my $img = new Image::Magick;
	$img->Read( $file );
	my ($w, $h) = $img->Get( 'columns', 'rows' );

	$img->Crop( width => 40, height => 32, x => $size{$fl} - 6, y => 0 );
	$img->Extent( width => 40, height => 32, x => 0, y => 0 );

	my $bg = new Image::Magick;
	$bg->Set( size => '40x32' );
	$bg->Read( "xc:white" );
	$bg->Composite( image => $img );


	my $min = 1;
	my $min_n = undef;
	foreach my $n ( keys %avg_2 ) {
		my $x = $bg->Compare( image => $avg_2{$n} );
		my ($e, $em) = $bg->Get( 'error', 'mean-error' );
		if ( $em < $min ) {
			$min = $em;
			$min_n = $n;
		}
		#print "X: $x, $n, $e, $em\n";
	}
	if ( $file =~ /^.$min_n/ ) {
		$ok++;
	} else {
		print "$file mismatch: $min_n\n";
		$nok++;
	}

	#print "$file: $w x $h\n";
}

print "OK: $ok, NOK: $nok\n";











my %avg_3;

foreach my $n ( @alph ) {

my $avg = new Image::Magick;

foreach my $file ( glob "??$n?*.gif" ) {
	my $img = new Image::Magick;
	$img->Read( $file );
	my ($w, $h) = $img->Get( 'columns', 'rows' );

	$img->Crop( width => 40, height => 32, x => $w - 56, y => 0 );
	$img->Extent( width => 40, height => 32, x => 0, y => 0 );

	my $bg = new Image::Magick;
	$bg->Set( size => '40x32' );
	$bg->Read( "xc:white" );
	$bg->Composite( image => $img );

	push @$avg, @$bg;
}

my $p = $avg->Average();
$p->Write("avg_3_$n.png");
print "Wrote avg_3_$n.png\n";

$avg_3{$n} = $p;
}

my $avg_3;
{
	my $avg = new Image::Magick;
	foreach ( sort keys %avg_3 ) {
		push @$avg, $avg_3{$_};
	}
	$avg_3 = $avg->Append(stack=>1);
	$avg_3->Write("avg_3_all.png");
}



$ok = 0;
$nok = 0;
foreach my $file ( glob "????*.gif" ) {
	my $img = new Image::Magick;
	$img->Read( $file );
	my ($w, $h) = $img->Get( 'columns', 'rows' );

	$img->Crop( width => 40, height => 32, x => $w - 56, y => 0 );
	$img->Extent( width => 40, height => 32, x => 0, y => 0 );

	my $bg = new Image::Magick;
	$bg->Set( size => '40x32' );
	$bg->Read( "xc:white" );
	$bg->Composite( image => $img );


	my $min = 1;
	my $min_n = undef;
	foreach my $n ( keys %avg_3 ) {
		my $x = $bg->Compare( image => $avg_3{$n} );
		my ($e, $em) = $bg->Get( 'error', 'mean-error' );
		if ( $em < $min ) {
			$min = $em;
			$min_n = $n;
		}
		#print "X: $x, $n, $e, $em\n";
	}
	if ( $file =~ /^..$min_n/ ) {
		$ok++;
	} else {
		print "$file mismatch: $min_n\n";
		$nok++;
	}

	#print "$file: $w x $h\n";
}

print "OK: $ok, NOK: $nok\n";











my %avg_4;

foreach my $n ( (1..9) ) {

my $avg = new Image::Magick;

foreach my $file ( glob "???$n*.gif" ) {
	my $img = new Image::Magick;
	$img->Read( $file );
	my ($w, $h) = $img->Get( 'columns', 'rows' );

	$img->Crop( width => 22, height => 32, x => $w - 22, y => 0 );
	$img->Extent( width => 22, height => 32, x => 0, y => 0 );

	my $bg = new Image::Magick;
	$bg->Set( size => '22x32' );
	$bg->Read( "xc:white" );
	$bg->Composite( image => $img );

	push @$avg, @$bg;
}

my $p = $avg->Average();
$p->Write("avg_4_$n.png");
print "Wrote avg_4_$n.png\n";
$avg_4{$n} = $p;
}



$ok = 0;
$nok = 0;
foreach my $file ( glob "????*.gif" ) {
	my $img = new Image::Magick;
	$img->Read( $file );
	my ($w, $h) = $img->Get( 'columns', 'rows' );

	$img->Crop( width => 22, height => 32, x => $w - 22, y => 0 );
	$img->Extent( width => 22, height => 32, x => 0, y => 0 );

	my $bg = new Image::Magick;
	$bg->Set( size => '22x32' );
	$bg->Read( "xc:white" );
	$bg->Composite( image => $img );


	my $min = 1;
	my $min_n = undef;
	foreach my $n ( keys %avg_4 ) {
		my $x = $bg->Compare( image => $avg_4{$n} );
		my ($e, $em) = $bg->Get( 'error', 'mean-error' );
		if ( $em < $min ) {
			$min = $em;
			$min_n = $n;
		}
		#print "X: $x, $n, $e, $em\n";
	}
	if ( $file =~ /^...$min_n/ ) {
		$ok++;
	} else {
		print "$file mismatch: $min_n\n";
		$nok++;
	}

	#print "$file: $w x $h\n";
}

print "OK: $ok, NOK: $nok\n";


my $avg_4;
{
	my $avg = new Image::Magick;
	foreach ( sort keys %avg_4 ) {
		push @$avg, $avg_4{$_};
	}
	$avg_4 = $avg->Append(stack=>1);
	$avg_4->Write("avg_4_all.png");
}

{
	my $avg = new Image::Magick;
	push @$avg, $avg_1;
	push @$avg, $avg_2;
	push @$avg, $avg_3;
	push @$avg, $avg_4;
	my $a = $avg->Append(stack=>0);
	$a->Quantize(colorspace=>'gray');
	$a->Write("avg_all.png");
}
