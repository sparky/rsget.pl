package RSGet::Get;
# This file is an integral part of rsget.pl downloader.
#
# 2009-2010 (c) Przemysław Iskra <sparky@pld-linux.org>
#		This program is free software,
# you may distribute it under GPL v2 or newer.

use strict;
use warnings;
use RSGet::Tools;
use RSGet::Captcha;
use RSGet::Form;
use RSGet::Wait;
use RSGet::Hook;
use RSGet::Quota;
use URI;
set_rev qq$Id$;

def_settings(
	debug => {
		desc => "Save errors.",
		default => 0,
		allowed => qr/\d/,
		type => "NUMBER",
	},
	tmpdir => {
		desc => "Directory where temporary files (cookies and dumps) are stored.",
		type => "PATH",
	},
	download_fail => {
		desc => "Command executed if download fails.",
		type => "COMMAND",
	},
);

BEGIN {
	our @ISA;
	@ISA = qw(RSGet::Wait RSGet::Captcha);
}

my %cookies;
sub make_cookie
{
	my $c = shift;
	my $cmd = shift;
	return () unless $c;
	unless ( $c =~ s/^!// ) {
		return if $cmd eq "check";
	}
	$cookies{ $c } = 1 unless $cookies{ $c };
	my $n = $cookies{ $c }++;

	local $_ = "cookie.$c.$n.txt";
	if ( my $dir = setting( "tmpdir" ) ) {
		$_ = $dir . "/" . $_;
	}
	unlink $_ if -e $_;
	return _cookie => $_;
}


sub new
{
	my ( $getter, $cmd, $uri, $options, $outif ) = @_;

	my $self = {
		_uri => $uri,
		_opts => $options,
		_try => 0,
		_cmd => $cmd,
		_pkg => $getter->{pkg},
		_outif => $outif,
		_id => randid(),
		_last_dump => 0,
		make_cookie( $getter->{cookie}, $cmd ),
	};
	bless $self, $getter->{pkg};
	$self->bestinfo();

	RSGet::FileList::update();

	if ( verbose( 2 ) or $cmd eq "get" ) {
		my $outifstr = $outif ? "[$outif]" :  "";

		hadd %$self,
			_line => new RSGet::Line( "[$getter->{short}]$outifstr ", undef, undef, "green" );
		$self->print( "start" );
		$self->linedata();
		$self->linecolor();
	}
	if ( $cmd eq "get" ) {
		local $SIG{__DIE__};
		delete $SIG{__DIE__};
		my $size = RSGet::ListManager::size_to_range( $self->{bestsize} );
		eval {
			hadd %$self,
				_quota => RSGet::Quota->new( $size->[1] || 50 * 1024 * 1024 );
		};
		if ( $@ ) {
			$self->delay( 600, "Quota reached: $@" );
			return undef;
		}
	}

	$self->call( \&start );
	return $self;
}

sub DESTROY
{
	my $self = shift;
	if ( my $c = $self->{_cookie} ) {
		unlink $c;
	}
}

sub log
{
	my $self = shift;
	my $text = shift;
	my $line = $self->{_line};
	return unless $line;

	my $outifstr = $self->{_outif} ? "[$self->{_outif}]" :  "";
	my $getter = RSGet::Plugin::from_pkg( $self->{_pkg} );
	new RSGet::Line( "[$getter->{short}]$outifstr ", $self->{_name} . ": " . $text );
}

sub search
{
	my $self = shift;
	my %search = @_;

	foreach my $name ( keys %search ) {
		my $search = $search{$name};
		if ( m/$search/ ) {
			$self->{$name} = $1;
		} else {
			$self->problem( "Can't find '$name': $search" );
			return 1;
		}
	}
	return 0;
}

sub form
{
	my $self = shift;
	return new RSGet::Form( $self->{body}, @_ );
}

sub print
{
	my $self = shift;
	my $text = shift;
	my $line = $self->{_line};
	return unless $line;
	$line->print( $self->{_name} . ": " . $text );
}

sub linedata
{
	my $self = shift;
	my @data = @_;
	my $line = $self->{_line};
	return unless $line;

	my %data = (
		name => $self->{bestname},
		size => $self->{bestsize},
		uri => $self->{_uri},
		@data,
	);

	$line->linedata( \%data );
}

sub linecolor
{
	my $self = shift;
	my $line = $self->{_line};
	my $color = shift;
	return unless $line;

	$line->color( $color );
}

sub start
{
	my $self = shift;

	foreach ( keys %$self ) {
		delete $self->{$_} unless /^_/;
	}
	delete $self->{_referer};
	$self->bestinfo();

	return $self->stage0();
}

sub call
{
	my $self = shift;
	my $func = shift;

	local $SIG{__DIE__};
	delete $SIG{__DIE__};
	eval {
		return &$func( $self, @_ );
	};
	if ( $@ ) {
		$self->problem( "function call problem: $@" );
	}
}

sub cookie
{
	my $self = shift;

	return unless $self->{_cookie};
	return if -r $self->{_cookie};

	open my $c, ">", $self->{_cookie};
	foreach my $line ( @_ ) {
		print $c join( "\t", @$line ), "\n";
	}
	close $c;
}

sub click
{
	my $self = shift;
	my @opts = @_;
	$self->{_click_opts} = \@opts;
	return $self->wait( \&click_start_get, irand( 2, 10 ),
		"clicking link", "delay" );
}

sub click_start_get
{
	my $self = shift;
	my @opts = @{ $self->{_click_opts} };
	delete $self->{_click_opts};
	return $self->get( @opts );
}

sub get
{
	my $self = shift;
	$self->{after_curl} = shift;
	my $uri = shift;

	$uri = URI->new( $uri )->abs( $self->{_referer} )->as_string
		if $self->{_referer};

	$self->linecolor( "green" );
	RSGet::Curl::new( $uri, $self, @_ );
}

sub get_finish
{
	my $self = shift;
	my $ref = shift;
	my $keep_ref = shift;
	$self->{_referer} = $ref unless $keep_ref;

	$self->dump() if setting( "debug" ) >= 2;

	my $func = $self->{after_curl};
	unless ( $func ) {
		$self->log( "WARNING: no after_curl" );
		return;
	}
	$_ = $self->{body};
	$self->call( $func );
}

sub click_download
{
	my $self = shift;
	my @opts = @_;
	$self->{_click_opts} = \@opts;
	return $self->wait( \&click_start_download, irand( 2, 10 ),
		"clicking download link", "delay" );
}

sub click_start_download
{
	my $self = shift;
	my @opts = @{ $self->{_click_opts} };
	delete $self->{_click_opts};
	return $self->download( @opts );
}

sub download
{
	my $self = shift;
	$self->{stage_is_html} = shift;
	my $uri = shift;

	$self->print("starting download");
	$self->get( \&finish, $uri, save => 1, @_ );
}

sub restart
{
	my $self = shift;
	my $time = shift || 1;
	my $msg = shift || "restarting";

	return $self->wait( \&start, $time, $msg, "restart" );
}

sub multi
{
	my $self = shift;
	my $msg = shift || "multi-download not allowed";
	if ( ++$self->{_try} < 4 ) {
		return $self->wait( \&start, - irand( 30, 120 ), $msg, "multi" );
	} else {
		return $self->delay( 300, $msg );
	}
}

# TODO: make delay interface-aware
sub delay
{
	my $self = shift;
	my $time = shift;
	my $msg = shift;
	$time = ( $self->{_opts}->{delay_last} || 0 ) + abs $time;
	my $until = $time + time;
	$msg = "Delayed until " . localtime( $until ) . ": " . $msg;

	$self->print( $msg ) || $self->log( $msg );
	RSGet::FileList::save( $self->{_uri}, options => { delay => $until, error => $msg, delay_last => $time } );
	RSGet::Dispatch::finished( $self );
}

sub finish
{
	my $self = shift;

	if ( $self->{is_html} ) {
		$self->print( "is HTML" );
		$_ = $self->{body};
		return $self->call( $self->{stage_is_html} );
	}

	RSGet::Dispatch::mark_used( $self );
	RSGet::FileList::save( $self->{_uri}, cmd => "DONE", options => { delay_last => undef } );
	RSGet::Dispatch::finished( $self );
}

sub abort
{
	my $self = shift;
	$self->print( $self->{_abort} || "aborted" );
	RSGet::Dispatch::finished( $self );
}

sub error
{
	my $self = shift;
	my $msg = shift;
	if ( $self->{body} and setting( "debug" ) ) {
		$self->dump();
	}

	$self->print( $msg ) || $self->log( $msg );
	RSGet::FileList::save( $self->{_uri}, options => { error => $msg } );
	RSGet::Dispatch::finished( $self );
	if ( my $call = setting( "download_fail" ) ) {
		RSGet::Hook::call( $call,
			uri => $self->{_uri},
			error => $msg,
			getter => $self->{_pkg},
			interface => $self->{_outif},
			command => $self->{_cmd},
		);
	}
}

sub problem
{
	my $self = shift;
	my $line = shift;
	my $msg = $line ? "problem at line: $line" : "unknown problem";
	$self->{_line}->clone->print( $self->{_name} . ": " . $msg ) if verbose( 4 );
	my $retry = 6;
	$retry = 3 if $self->{_cmd} eq "check";
	if ( ++$self->{_try} < $retry ) {
		return $self->wait( \&start, -2 ** $self->{_try}, $msg, "problem" );
	} elsif ( $self->{_cmd} eq "check" ) {
		return $self->error( $msg . ", aborting" );
	} else {
		return $self->delay( 10 * 60, $msg );
	}
}

sub dump
{
	my $self = shift;
	my ( $body, $ext );
	my $ct = $self->{content_type} || "undef";
	if ( @_ >= 2 ) {
		$body = shift;
		$ct = $ext = shift;
	} else {
		$body = $self->{body};
		if ( $ct =~ /javascript/ ) {
			$ext = "js";
		} elsif ( $ct =~ /(ht|x)ml/ ) {
			$ext = "html";
		} elsif ( $ct =~ m{image/(\S+)} ) {
			$ext = $1;
		} else {
			$ext = "txt";
		}
	}

	unless ( defined $body ) {
		$self->log( "body not defined, not dumping ($ct, $ext)" );
		return;
	}

	my $dir = setting( "tmpdir" ) || "";
	$dir .= "/" if $dir;

	my $file = sprintf "${dir}dump.$self->{_id}.%.4d.$ext",
		++$self->{_last_dump};

	open my $f_out, '>', $file;
	print $f_out $body;
	close $f_out;

	$self->log( "dumped to file: $file ($ct)" );
}

sub bestinfo
{
	my $self = shift;
	my $o = $self->{_opts};

	my $bestname = $o->{fname}
		|| $o->{name} || $o->{iname}
		|| $o->{aname} || $o->{ainame};
	unless ( $bestname ) {
		my $uri = $self->{_uri};
		$bestname = ($uri =~ m{([^/]+)/*$})[0] || $uri;
	}
	$self->{bestname} = $bestname;
	$bestname =~ s/\0/(?)/;
	$self->{_name} = $bestname;

	my $bestsize = $o->{fsize}
		|| $o->{size} || $o->{asize}
		|| "?";
	$self->{bestsize} = $bestsize;
}

sub info
{
	my $self = shift;
	my %info = @_;
	$info{asize} =~ s/\s+//g if $info{asize};
	RSGet::FileList::save( $self->{_uri}, options => \%info );

	hadd( %{$self->{_opts}}, %info );
	$self->bestinfo();

	return 0 unless $self->{_cmd} eq "check";
	p "info( $self->{_uri} ): $self->{bestname} ($self->{bestsize})\n"
		if verbose( 1 );
	RSGet::Dispatch::finished( $self );
	return 1;
}

sub link
{
	my $self = shift;
	return $self->error( "plugin found 0 links" ) unless @_;
	my %links;
	my $i = 0;
	foreach ( @_ ) {
		$links{ "link" . ++$i } = $_;
	}
	RSGet::FileList::save( $self->{_uri}, cmd => "DONE",
		links => [ @_ ], options => \%links );
	RSGet::Dispatch::finished( $self );
	return 1;
}

sub started_download
{
	my $self = shift;
	my %opts = @_;
	my $fname = $opts{fname};
	my $fsize = $opts{fsize};

	my $o = $self->{_opts};
	$o->{fname} = $fname;
	$o->{fsize} = $fsize;
	$self->bestinfo();

	my @osize;
	@osize = ( fsize => $fsize ) if $fsize > 0;

	$self->{started_download} = 1;

	RSGet::FileList::save( $self->{_uri},
		globals => { fname => $fname, fsize => $fsize },
		options => { fname => $fname, @osize } );
	RSGet::FileList::update();

	$self->captcha_result( "ok" );
}

1;

# vim: ts=4:sw=4
