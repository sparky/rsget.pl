package RSGet::Dispatch;
# This file is an integral part of rsget.pl downloader.
#
# 2009-2010 (c) Przemysław Iskra <sparky@pld-linux.org>
#		This program is free software,
# you may distribute it under GPL v2 or newer.

use strict;
use warnings;
use RSGet::Tools;
set_rev qq$Id$;

def_settings(
	max_slots => {
		desc => "Number of slots (per IP) to use if getter has no limitation.",
		default => 8,
		allowed => qr/0*[1-9]\d*/,
		type => "NUMBER",
	},
	max_slots_check => {
		desc => "Number of slots per service (per IP) to use when checking file information.",
		default => 8,
		allowed => qr/0*[1-9]\d*/,
		type => "NUMBER",
	},

);

our %downloading;
our %checking;

my $soft_stop = 0;

my %working = (
	get => \%downloading,
	check => \%checking,
);

my @interfaces;
sub add_interface
{
	my $newifs = shift;
	NEW_IP: foreach my $new_if ( split /[ ,]+/, $newifs ) {
		foreach my $old_if ( @interfaces ) {
			if ( $new_if eq $old_if ) {
				print "Address $new_if already on the list\n";
				next NEW_IP;
			}
		}
		p "Adding $new_if interface/address\n";
		push @interfaces, $new_if;
	}
}

sub remove_interface
{
	my $if = shift;
	my $reason = shift;
	for ( my $i = 0; $i < @interfaces; $i++ ) {
		next unless $interfaces[ $i ] eq $if;
		my $removed = splice @interfaces, $i, 1;
		warn "Removed interface '$removed': $reason\n";
	}

	die "No working interfaces left\n" unless @interfaces;
}

my $delay_check;
sub delay_check
{
	return unless $delay_check and $delay_check <= time;
	RSGet::FileList::update();
	$delay_check = undef;
}

my %last_used;

sub find_free_if
{
	my $pkg = shift;
	my $working = shift;
	my $slots = shift;

	unless ( scalar @interfaces ) {
		my $running = 0;
		foreach ( values %$working ) {
			$running++ if $_->{_pkg} eq $pkg
		}
		#p "running: $running / $slots";
		return undef if $running >= $slots;
		return "";
	}

	my %by_pos = map { $interfaces[ $_ ] => $_ } (0..$#interfaces);
	my %by_if = map { $_ => 0 } @interfaces;
	foreach ( values %$working ) {
		next unless $_->{_pkg} eq $pkg;
		$by_if{ $_->{_outif} }++;
	}

	my $min = $slots;
	grep { $min = $_ if $_ < $min } values %by_if;
	return undef if $min >= $slots;

	my $lu = $last_used{$pkg} ||= {};
	my @min_if = sort {
		my $_a = $lu->{ $a } || $by_pos{ $a };
		my $_b = $lu->{ $b } || $by_pos{ $b };
		$_a <=> $_b
	} grep { $by_if{ $_ } <= $min } keys %by_if;
	return $min_if[ 0 ];
}

sub mark_used
{
	my $obj = shift;
	my $if = $obj->{_outif};
	return unless $if;
	my $pkg = $obj->{_pkg};
	my $lu = $last_used{$pkg} ||= {};
	$lu->{$if} = time;
}

sub finished
{
	my $obj = shift;
	my $status = shift;

	my ( $uri, $cmd ) = @$obj{ qw(_uri _cmd) };
	my $working = $working{ $cmd };
	delete $working->{ $uri };


	RSGet::FileList::update();
}

sub get_slots
{
	my $cmd = shift;
	my $suggested = shift;
	$suggested = "1" unless defined $suggested;
	if ( $cmd eq "check" ) {
		my $max = setting( "max_slots_check" );
		if ( $suggested =~ /^!(\d+)/ ) {
			return $max < $1 ? $max : $1;
		}
		return $max;
	} else {
		my $max = setting( "max_slots" );
		$suggested =~ s/^!//;
		if ( $suggested =~ /^\d+$/ ) {
			return $max < $suggested ? $max : $suggested;
		}
		return $max if lc $suggested eq "max";
		warn "Invalid slots declaration: $suggested\n" if verbose( 1 );
		return 1;
	}
}

sub run
{
	my ( $cmd, $uri, $getter, $options ) = @_;
	my $class = $getter->{class};

	if ( $options->{delay} ) {
		if ( not $options->{error} or not $options->{error} =~ /^Delayed until/ ) {
			delete $options->{delay};
			RSGet::FileList::save( $uri, options => { delay => undef } );
		} elsif ( $options->{delay} < time ) {
			delete $options->{delay};
			delete $options->{error};
			RSGet::FileList::save( $uri, options => { delay => undef, error => undef } );
		} else {
			$delay_check = $options->{delay}
				if not $delay_check or $delay_check > $options->{delay};
		}
	}
	return if $options->{error};

	my $working = $working{ $cmd };
	my $w = $working->{ $uri };
	return $w if defined $w;

	my $pkg = $getter->{pkg};
	my $outif = find_free_if( $pkg, $working, get_slots( $cmd, $getter->{slots} ) );
	return unless defined $outif;

	my $obj = $getter->start( $cmd, $uri, $options, $outif );
	if ( not $obj and $getter->{error} ) {
		$options->{error} = $getter->{error};
		return;
	}
	$working->{ $uri } = $obj if $obj;
	
	return $obj;
}

sub check
{
	my $uri = shift;
	my $getter = shift;
	my $options = shift;

	return $options if $options->{error};
	return $options if $options->{size} or $options->{asize};
	return $options if $options->{quality};
	return $options if $options->{link1};

	run( "check", $uri, $getter, $options );
	return undef;
}

sub process
{
	my $getlist = shift;

	my $time = shift;
	my %num_by_pkg;
	my %all_uris;
	my $to_dl = 0;
	foreach my $line ( @$getlist ) {
		next unless ref $line;
		my $uris = $line->{uris};
		my $cmd = $line->{cmd};

		if ( $cmd eq "STOP" ) {
			foreach my $uri ( keys %$uris ) {
				if ( my $obj = $downloading{$uri} ) {
					$obj->{_abort} = "Stopped";
				}
			}
			next;
		}
		next unless $cmd eq "GET";

		$to_dl++;
		foreach my $uri ( keys %$uris ) {
			my ( $getter, $opts ) = @{ $uris->{ $uri } };
			if ( $opts->{error} ) {
				if ( my $obj = $downloading{$uri} ) {
					$obj->{_abort} = "Stopped";
				}
				next unless $opts->{delay};
			}
			$all_uris{ $uri } = 1;
			my $pkg = $getter->{pkg};
			$num_by_pkg{ $pkg } ||= 0;
			$num_by_pkg{ $pkg }++;
		}
	}

	abort_missing( \%all_uris, \%downloading );

	my $downloading_num = scalar grep { $_->{started_download} } values %downloading;
	RSGet::Line::status(
		'to download' => $to_dl,
		'running' => scalar keys %downloading,
		'downloading' => $downloading_num,
		'checking URIs' => scalar keys %checking,
	);

	if ( $soft_stop ) {
		foreach my $obj ( values %downloading ) {
			unless ( $obj->{started_download} ) {
				$obj->{_abort} = "Soft restart";
			}
		}
		unless ( $downloading_num ) {
			if ( $soft_stop == 2 ) {
				RSGet::Main::restart()
			} else {
				RSGet::Main::stop()
			}
		}
		return 1;
	}

	my $all_checked = 1;
	EACH_LINE: foreach my $line ( @$getlist ) {
		next unless ref $line;

		my ( $cmd, $globals, $uris ) = @$line{ qw(cmd globals uris) };
		next if $cmd eq "DONE";

		my %pkg_by_uri;

		foreach my $uri ( keys %$uris ) {
			my ( $getter, $options ) = @{ $uris->{ $uri } };
			$pkg_by_uri{ $uri } = $getter->{pkg};
			my $chk = check( $uri, $getter, { %$options, %$globals } );
			$all_checked = 0 unless $chk;
		}

		next unless $all_checked;
		next unless $cmd eq "GET";

		# is it running already ?
		foreach my $uri ( keys %$uris ) {
			next EACH_LINE if $working{get}->{ $uri };
		}

		foreach my $uri ( sort {
					( $num_by_pkg{ $pkg_by_uri{ $a } } || 0 )
						<=>
					( $num_by_pkg{ $pkg_by_uri{ $b } } || 0 )
				} keys %$uris ) {
			my ( $getter, $options ) = @{ $uris->{ $uri } };
			next EACH_LINE if run( "get", $uri, $getter, { %$options, %$globals } );
		}
	}

	return $all_checked;
}

sub soft_restart
{
	if ( $soft_stop == 2 ) {
		RSGet::Main::restart();
	} else {
		$soft_stop = 2;
		warn "* rsget.pl will restart after finishing all current downloads\n";
		warn "* send SIGUSR2 again to restart now\n";
		RSGet::FileList::update();
	}
}

$SIG{USR2} = \&soft_restart;

sub soft_segv
{
	warn "* segment violation detected\n";
	if ( $soft_stop == 0 ) {
		$soft_stop = 2;
		warn "* rsget.pl will restart after finishing all current downloads\n";
		warn "* send SIGUSR2 to restart now\n";
		RSGet::FileList::update();
	}
}
$SIG{SEGV} = \&soft_segv;

sub soft_stop
{
	if ( $soft_stop == 1 ) {
		RSGet::Main::stop();
	} else {
		$soft_stop = 1;
		warn "* rsget.pl will terminate after finishing all current downloads\n";
		warn "* send SIGINT again to terminate now\n";
		RSGet::FileList::update();
	}
}

$SIG{INT} = \&soft_stop;

sub abort_missing
{
	my $all = shift;
	my $running = shift;
	foreach ( keys %$running ) {
		next if $all->{$_};
		my $obj = $running->{$_};
		$obj->{_abort} = "Stopped or removed from the list!";
	}
}

1;

# vim: ts=4:sw=4
