package RSGet::Main;
#
# 2009 (c) Przemysław Iskra <sparky@pld-linux.org>
# Use/modify/distribute under GPL v2 or newer.
#
use strict;
use warnings;
use RSGet::AutoUpdate;
use RSGet::Captcha;
use RSGet::Curl;
use RSGet::Dispatch;
use RSGet::FileList;
use RSGet::Get;
use RSGet::MortalObject;
use RSGet::Line;
use RSGet::ListManager;
use RSGet::Processor;
use RSGet::Tools;
use RSGet::Wait;
use Time::HiRes;
set_rev qq$Id$;

def_settings(
	interfaces => {
		desc => "Specify output interfaces or IP addresses.",
	},
	http_port => {
		desc => "Start HTTP server on specified port.",
		allowed => qr/\d+/,
	},
	http_pass => {
		desc => "HTTP password, as plain text, user is 'root'.",
		allowed => qr/\S+/,
	},
	verbose => {
		desc => "Verbosity level.",
		default => 0,
		allowed => qr/\d+/,
	},
	userconfig => {
		desc => "User configuration file.",
		allowed => qr/.+/,
	},
);

our %usettings;

my $http = undef;
sub init
{
	my $help = shift;
	my $main_rev = shift;
	my $argv = shift;
	my $ifs = shift;
	set_rev $main_rev;

	print_help() if $help;
	check_settings();

	$SIG{CHLD} = "IGNORE";
	maybe_update( $argv );
	read_userconfig();
	RSGet::Line::init();
	print_settings() if verbose( 1 );
	RSGet::FileList::set_file();
	maybe_start_http();
	set_interfaces( $ifs );

	new RSGet::Line();

	find_getters();

	new RSGet::Line();
	new RSGet::Line( "rsget.pl started successfully" );
	new RSGet::Line();
	RSGet::Line::update();

	loop();
}

sub print_help
{
	require Term::Size;
	my ( $columns, $rows ) = Term::Size::chars;
	print "Usage: $0 [OPTIONS] [LIST FILE]\n";
	print "Downloads files from services like RapidShare.\n\n";
	print "Arguments are always mandatory.\n";
	$columns = 80 if $columns < 40;
	my $optlen = 20;
	my $textlen = $columns - $optlen - 1;
	foreach my $s ( sort keys %main::def_settings ) {
		my $option = "  --$s=VAL";
		my $l = length $option;
		if ( $l > $optlen ) {
			print $option . "\n" . " " x $optlen;
		} else {
			print $option . " " x ( $optlen - $l );
		}
		my @text = split /\s+/, $main::def_settings{ $s }->{desc};
		my $defval = $main::def_settings{ $s }->{default};
		push @text, "Default:", $defval if defined $defval;
		my $line = "";
		foreach my $word ( @text ) {
			if ( length( $word ) + length( $line ) > $textlen - 4 ) {
				print $line . "\n" . " " x ($optlen + 2);
				$line = "";
			}
			$line .= " " . $word;
		}
		print $line . "\n";
	}
	print "\n";

	exit 0;
}

sub maybe_update
{
	my $argv = shift;
	if ( setting( "use_svn" ) eq "update" ) {
		if ( RSGet::AutoUpdate::update() ) {
			warn "Update successful, restarting\n";
			exec $0, @$argv, "--use_svn", "yes";
		}
		main::set( "use_svn", "yes", "SVN updated" );
	}
}

sub check_settings
{
	my $die = 0;
	foreach my $s ( sort keys %main::settings ) {
		my $v = $main::settings{ $s };
		my $def = $main::def_settings{ $s };
		unless ( $def ) {
			warn "There is no setting '$s' -- defined in $v->[1].\n";
			$die = 1;
			next;
		}
		my $value = $v->[0];
		if ( my $re = $def->{allowed} ) {
			unless ( $value =~ m/^$re$/ ) {
				warn "Setting '$s' has invalid value: '$value' -- defined in $v->[1].\n";
				$die = 1;
				next;
			}
		}
	}
	die "ERROR: Found invalid settings.\n" if $die;
}

sub print_settings
{
	p "Settings:";
	foreach my $s ( sort keys %main::settings ) {
		my $v = $main::settings{ $s };
		my $def = "";
		$def = " \t($v->[1])" if verbose( 2 );
		p "  $s => $v->[0]$def";
	}
}

sub maybe_start_http
{
	my $port = setting( "http_port" );
	return unless $port;

	require RSGet::HTTPServer;
	$http = new RSGet::HTTPServer( $port );
	if ( $http ) {
		p "HTTP server started on port $port";
	} else {
		warn "HTTP server failed (port $port)\n";
	}
}

sub read_userconfig
{
	my $cfg = setting( "userconfig" );
	return unless $cfg;
	die "Cannot read user config '$cfg' file\n" unless -r $cfg;

	my $line = 0;
	my $user = undef;
	open F_IN, "<", $cfg;
	while ( <F_IN> ) {
		$line++;
		next if /^\s*(?:#.*)?$/;
		chomp;
		if ( /^\s*\[([a-zA-Z0-9_]+)\]\s*$/ ) {
			$user = $1;
			$usettings{ $user } = {};
			next;
		} elsif ( /^\s*([a-z_]+)\s*=\s*(.*?)\s*$/ ) {
			die "User not defined, at user config file, line ($line):\n$_\n"
				unless $user;
			$usettings{ $user }->{$1} = [ $2, "user config file, line $line" ];
			next;
		}
		warn "Incorrect config line: $_\n";
	}
	close F_IN;


}

sub set_interfaces
{
	my $ifs = shift;
	my $if = setting( "interfaces" );
	RSGet::Dispatch::add_interface( $if ) if $if;
	foreach my $if ( @$ifs ) {
		RSGet::Dispatch::add_interface( $if );
	}
}

sub find_getters
{
	my @paths = ( $main::install_path );
	if ( setting( "use_svn" ) eq "yes" ) {
		unshift @paths, $main::local_path;
	}
	foreach my $path ( @paths ) {
		foreach my $type ( qw(Get Link Video) ) {
			my $dir = "$path/$type";
			next unless -d $dir;
			foreach ( sort glob "$path/$type/*" ) {
				add_getter( $type, $_ );
			}
		}
	}
}

sub add_getter
{
	my $type = shift;
	local $_ = shift;
	return if /~$/;
	return if m{/\.[^/]*$};
	( my $file = $_ ) =~ s#.*/##;
	return if exists $getters{ $type . "::" . $file };
	my ( $pkg, $getter ) = RSGet::Processor::read_file( $type, $_ );
	my $msg = "${type}/$file: failed";
	if ( $pkg and $getter ) {
		$getters{ $pkg } = $getter;
		$msg = "$pkg: added\n";
		new RSGet::Line( "INIT: ", $msg );
	} else {
		warn "$msg\n";
	}
}

sub loop
{
	# main loop
	my $lasttime = 0;
	for (;;) {
		if ( RSGet::Curl::need_run() ) {
			RSGet::Curl::maybe_abort();
			foreach ( 0..4 ) {
				RSGet::Curl::perform();
				Time::HiRes::sleep(0.050);
			}
		} else {
			Time::HiRes::sleep(0.250);
		}
		RSGet::Curl::update_status();
		RSGet::Line::update();
		$http->perform() if $http;

		my $time = time;
		next if $time == $lasttime;
		$lasttime = $time;
	
		RSGet::Wait::wait_update();
		RSGet::MortalObject::update();
		RSGet::Captcha::captcha_update();

		my $getlist = RSGet::FileList::readlist();
		if ( $getlist ) {
			my $allchk = RSGet::Dispatch::process( $getlist );
			RSGet::ListManager::autoadd( $getlist );
		}
	}
}

1;
# vim:ts=4:sw=4
