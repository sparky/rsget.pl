package RSGet::Hook;
# This file is an integral part of rsget.pl downloader.
#
# 2010 (c) Przemysław Iskra <sparky@pld-linux.org>
#		This program is free software,
# you may distribute it under GPL v2 or newer.

use strict;
use warnings;
use RSGet::Tools;
use RSGet::Line;
set_rev qq$Id$;

sub shquote
{
	local $_ = shift;
	s/'/'"'"'/g;
	return "'$_'";
}

sub call
{
	my $hook = shift;
	my %opts = @_;

	$hook =~ s/(\$\(([a-z]*)\))/shquote( $opts{ $2 } || $1 )/eg;

	my $pid = fork;
	unless ( defined $pid ) {
		warn "Fork failed\n";
	}
	if ( $pid ) {
		p "Executing '$hook'\n" if verbose( 1 );
	} else {
		close STDIN;
		close STDOUT;
		close STDERR;
		exec $hook;
		die "Exec failed: $@\n";
	}
}


1;

# vim: ts=4:sw=4
