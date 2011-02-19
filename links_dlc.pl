#!/usr/bin/perl
#
# 2011 (c) Przemysław Iskra <sparky@pld-linux.org>
#		This program is free software,
# you may distribute it under GPL v2 or newer.
use strict;
use warnings;
use Crypt::Rijndael;
use MIME::Base64;

$/ = undef;

# hide from google
my @str = (
	'<=ff=j<=<mk;=lfg' ^ "_" x 16,
	'f=<mk<=ffj<=g;=l' ^ "_" x 16,
	'fzz~4!!}k|xgmk djay`baojk| a|i!jbm|w~z!}k|xgmk ~f~1}|mZw~k3jbm(jk}zZw~k3~wba(jozo3' ^ chr( 14 ) x 82,
);

my $dlcdata = <>;
$dlcdata =~ s/\s+//gs;
$dlcdata =~ s/=?=?$/==/s;

my $key = substr $dlcdata, -88, 88, '';

open my $rcf, "-|", qw(wget -O - -q), $str[ 2 ] . $key;
my $rc = <$rcf>;
close $rcf;

$rc =~ m#<rc>(.+)</rc>#s;
$rc = decode_base64( $1 );

my $crypt = Crypt::Rijndael->new( $str[ 0 ], Crypt::Rijndael::MODE_CBC() );
$crypt->set_iv( $str[ 1 ] );
my $dlckey = $crypt->decrypt( $rc );

$crypt = Crypt::Rijndael->new( $dlckey, Crypt::Rijndael::MODE_CBC() );
$crypt->set_iv( $dlckey );

my $data = decode_base64( $crypt->decrypt( decode_base64( $dlcdata ) ) );
while ( $data =~ s#<file>(.+?)</file>##s ) {
	local $_ = $1;
	m#<url>(.*?)</url>#;
	print "ADD: " . decode_base64( $1 ) . "\n";
}
