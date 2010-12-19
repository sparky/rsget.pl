package RSGet::MOTD;
# This file is an integral part of rsget.pl downloader.
#
# 2010 (c) Przemysław Iskra <sparky@pld-linux.org>
#		This program is free software,
# you may distribute it under GPL v2 or newer.

use strict;
use warnings;
use RSGet::Line;

sub init
{
	my @motd = grep /^-/, <DATA>;
	close DATA;
	my $motd = $motd[ int rand scalar @motd ];
	$motd =~ s/-\s*//;
	RSGet::Line->new( "Hint: ", $motd, undef, "green" );
}

1;

__DATA__

- Join us on IRC: #rsget.pl on irc.freenode.net

- If you have a subversion client you can enable automatic updates with --use-svn=update

- You can always get latest rsget.pl snapshot from http://rsget.pl/download/snapshot

- Send SIGUSR2 if you want to restart rsget.pl

- Sending SIGINT once will not terminate your current downloads

- Use gtk asker for convenient captcha solving: http://rsget.pl/tools/gtk-captcha/

- Use userscript to easily add multiple download links from your web browser: http://rsget.pl/tools/userscript/

- Donate/lend premium accounts to rsget.pl developers if you want premium support for some service.

- Found some bug ? Tell us about it: http://bugs.rsget.pl

# vim: ts=4:sw=4
