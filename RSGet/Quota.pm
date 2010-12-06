package RSGet::Quota;
# This file is an integral part of rsget.pl downloader.
#
# 2009-2010 (c) Przemysław Iskra <sparky@pld-linux.org>
#		This program is free software,
# you may distribute it under GPL v2 or newer.

use strict;
use warnings;
use RSGet::Tools;
set_rev qq$Id: Wait.pm 11838 2010-10-09 18:56:30Z sparky $;

def_settings(
	quota_soft => {
		desc => "Start downloads only if ammount of downloaded data is less "
			. "than quota_soft bytes.",
		allowed => qr/\d+[gmk]?b?/i,
	},
	quota_hard => {
		desc => "Don't start downloads if they may excede quota_hard bytes.",
		allowed => qr/\d+[gmk]?b?/i,
	},
);

my $quota_soft = undef;
my $quota_hard = undef;

my $quota_used = 0;

sub _get_quota
{
	my $name = shift;

	my $s = setting( $name );
	return undef unless $s;

	return RSGet::ListManager::size_to_range( $s )->[0];
}

sub _init
{
	$quota_soft = _get_quota( "quota_soft" );
	$quota_hard = _get_quota( "quota_hard" );
	$quota_used = 0;
}

sub new
{
	my $class = shift;
	my $size = shift;

	die "soft quota reached\n"
		if $quota_soft and $quota_used > $quota_soft;
	die "hard quota reached\n"
		if $quota_hard and $quota_used + $size > $quota_hard;

	$quota_used += $size;
	my $self = \$size;

	bless $self, $class;
}

# update (i.e. no we know we won't have to download whole file)
sub update
{
	my $self = shift;
	my $size = shift;

	$quota_used -= $$self;
	$$self = $size;
	$quota_used += $$self;

	return $quota_used <= $quota_hard
		if $quota_hard;
	return 1;
}

# confirm number of bytes downloaded
sub confirm
{
	my $self = shift;
	my $size = shift;

	$quota_used -= $$self;
	$$self = 0;
	$quota_used += $size;

	return $size;
}

# undo unless confirmed
sub DESTROY
{
	my $self = shift;

	$quota_used -= $$self;
}

1;

# vim: ts=4:sw=4
