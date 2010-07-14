package RSGet::FileList;
# This file is an integral part of rsget.pl downloader.
#
# 2009-2010 (c) Przemysław Iskra <sparky@pld-linux.org>
#		This program is free software,
# you may distribute it under GPL v2 or newer.

use strict;
use warnings;
use URI::Escape;
use Fcntl qw(:DEFAULT :flock SEEK_SET);
use IO::Handle;
use RSGet::Tools;
set_rev qq$Id$;

def_settings(
	list_lock => {
		desc => "If lock file exists, list file won't be updated.",
		default => '$(dir)/.$(file).swp',
		allowed => qr/.+/,
		type => "PATH",
		user => 1,
	},
	list_file => {
		desc => "Use specified file as URI list.",
		allowed => qr/.+/,
		type => "PATH",
		user => 1,
	}
);

my $file;
my $file_swp;
my $list_fh;

my $update = 1;
# $uri => { cmd => "CMD", globals => {...}, options => {...} }

# commands:
# GET - download
# DONE - stop, fully downloaded
# STOP - stop, partially downloaded
# ADD - add as clone if possible, new link otherwise

our @actual;
our @added;

sub list_open
{
	my $file = shift;
	sysopen my $fh, $file, O_RDWR | O_CREAT or die "Cannot open $file: $!\n";
	flock $fh, LOCK_EX | LOCK_NB or die "Cannot lock $file: $!\n";
	seek $fh, 0, SEEK_SET;
	return $fh;
}

sub list_close
{
	my $fh = shift;
	flock $fh, LOCK_UN;
	return close $fh;
}

END {
	list_close $list_fh if $list_fh;
}

sub set_file
{
	$file = setting( "list_file" );
	unless ( defined $file ) {
		$file = 'get.list';
		unless ( -r $file ) {
			p "Creating empty file list '$file'";
			$list_fh = list_open $file;
			print $list_fh "# empty list\n";
		}
	}
	unless ( $list_fh ) {
		p "Using '$file' file list\n";
		$list_fh = list_open $file;
	}
	die "Can't read '$file'\n" unless -r $file;

	{
		my ( $dir, $fn );
		if ( $file =~ m{^(.*)/(.*?)$} ) {
			$dir = $1;
			$fn = $2;
		} else {
			$dir = '.';
			$fn = $file;
		}
		$file_swp = setting( "list_lock" );
		$file_swp =~ s/\$\(file\)/$fn/g;
		$file_swp =~ s/\$\(dir\)/$dir/g;
		p "Using '$file_swp' as file lock\n";
	}
}

sub update
{
	$update = 1;
}

our %save; # options to be saved
sub save
{
	my $uri = shift;
	my %data = @_;
	my $save_uri = $save{ $uri } ||= {};
	foreach my $key ( keys %data ) {
		my $val = $data{ $key };
		if ( $key =~ /^(options|globals|clones)/ ) {
			my $hash = $save_uri->{ $key } ||= {};
			hadd $hash, %{ $val };
		} else {
			$save_uri->{ $key } = $val;
		}
	}
}

$RSGet::Dispatch::downloading if 0; # avoid warning
sub proc_stop_inactive_get
{
	return unless $_[0] eq "GET";

	foreach my $uri ( keys %{$_[2]} ) {
		return if exists $RSGet::Dispatch::downloading{ $uri };
	}

	$_[0] = "STOP";
}

our %processors = (
	"Remove all DONE" => sub {
		if ( $_[0] eq "DONE" ) {
			my $decoded = $_[2];
			delete $decoded->{$_} foreach keys %$decoded;
		}
	},
	"Remove all STOP" => sub {
		if ( $_[0] eq "STOP" ) {
			my $decoded = $_[2];
			delete $decoded->{$_} foreach keys %$decoded;
		}
	},
	"Start all STOP" => sub {
		$_[0] = "GET" if $_[0] eq "STOP";
	},
	"Stop all GET" => sub {
		$_[0] = "STOP" if $_[0] eq "GET";
	},
	"Stop inactive GET" => \&proc_stop_inactive_get,
	"Restart errors" => sub {
		my $cleared = 0;
		foreach my $data ( values %{$_[2]} ) {
			if ( $data->[1]->{error} and $data->[1]->{error} ne "disabled" ) {
				delete $data->[1]->{error};
				$cleared = 1;
			}
		}
		$_[0] = "GET" if $cleared and $_[0] eq "STOP";
	},
	"Clear errors" => sub {
		foreach my $data ( values %{$_[2]} ) {
			delete $data->[1]->{error}
				if ( $data->[1]->{error} || "" ) ne "disabled"
		}
	},
	"Clear disabled" => sub {
		foreach my $data ( values %{$_[2]} ) {
			delete $data->[1]->{error}
				if ( $data->[1]->{error} || "" ) eq "disabled"
		}
	},
);
our %processors_title = (
	"Remove all DONE" => 'Remove from download list all files with DONE status',
	"Remove all STOP" => 'Remove from download list all files with STOP status',
	"Start all STOP" => 'Restart all files with STOP status (must not have error)',
	"Stop all GET" => 'Stop all active files (including active downloads)',
	"Stop inactive GET" => 'Stop files with GET status which are not being downloaded',
	"Restart errors" => 'Clear error messages and restart if status is STOP',
	"Clear errors" => 'Clear all error messages (but not "disabled")',
	"Clear disabled" => 'Clear all "disabled" errors',
);

my $process = undef;
sub process
{
	my $name = shift;
	if ( $processors{ $name } ) {
		$process = $processors{ $name };
		$update = 1;
	}
}


sub h2a($)
{
	my $h = shift;
	return map { defined $h->{$_} ? ($_ . "=" . uri_escape( $h->{$_} )) : () } sort keys %$h;
}

our $listmtime = 0;
sub readlist
{
	return unless -r $file;
	my $mtime = (stat _)[9];
	return unless $update or $mtime != $listmtime;

	list_close $list_fh;
	$list_fh = list_open $file;
	my @list = <$list_fh>;

	push @list, @added;

	my @new;

	my @used_save;
	my %all_uri;
	@actual = ();
	while ( my $line = shift @list ) {
		chomp $line;
		if ( $line =~ /^__END__\s*$/ ) { # end of the list
			push @new, $line . "\n";
			push @actual, $line;
			push @new, @list;
			push @actual, @list;
			last;
		}
		if ( $line =~ /^\s*(#.*)?$/ ) { # comments and empty lines
			push @new, $line . "\n";
			push @actual, $line;
			next;
		}
		my $mline = $line;
		while ( $mline =~ s/\s*\\$/ / or (@list and $list[0] =~ s/^\s*\+\s*/ /) ) { # stitch broken lines together
			$line = shift @list;
			chomp $line;
			$mline .= $line;
		}

		$mline =~ s/^\s+//s;
		$mline =~ s/\s+$//s;
		my @words = split /\s+/s, $mline;


		my $cmd;
		if ( $words[0] =~ /^(GET|DONE|STOP|ADD):$/ ) {
			$cmd = $1;
			shift @words;
		}
		my $globals = {};
		my $options = $globals;

		my %decoded;
		my @invalid;
		my $protos = qr{(?:http|https|ftp|rtmp|rtmpt?(?:|e|s)|rtspu?)://}o;
		foreach ( @words ) {
			if ( /^([a-z0-9_]+)=(.*)$/ ) {
				$options->{$1} = uri_unescape( $2 );
				next;
			} elsif ( m{^($protos)?(.*?\..*?/.*)$}o or m{^($protos)(\S+?\.\S+)$}o ) {
				my $proto = $1 || "http://";
				my $uri = $proto . $2;
				$options = {};
				$decoded{ $uri } = $options;
				next;
			}

			push @invalid, $_;
		}

		unless ( keys %decoded ) {
			my $line = '# invalid line: ' . (join " ", ($cmd ? "$cmd:" : ()), @words);
			push @new, $line . "\n";
			push @actual, $line;
			next;
		}

		foreach my $uri ( keys %decoded ) {
			my $opt = $decoded{ $uri };
			my $getter;
			if ( $opt->{getter} and $getter = RSGet::Plugin::from_pkg( $opt->{getter} ) ) {
				$decoded{ $uri } = [ $getter, $opt ];
			} else {
				$getter = RSGet::Plugin::from_uri( $uri );
				if ( $getter ) {
					my $newuri = $getter->unify( $uri );
					$opt->{getter} = $getter->{pkg};
					$decoded{ $newuri } = [ $getter, $opt ];
					delete $decoded{ $uri } if $newuri ne $uri;
				} else {
					my $line = "# invalid uri: $uri " . (join " ", h2a( $opt ));
					push @new, $line . "\n";
					push @actual, $line;
					delete $decoded{ $uri };
				}
			}
		}

		unless ( keys %decoded ) {
			if ( my @a = h2a( $globals ) ) {
					my $line = "# lost options: " . (join " ", @a);
					push @new, $line . "\n";
					push @actual, $line;
			}
			next;
		}

		if ( @invalid ) {
			my $line = '# invalid: ' . (join " ", @invalid);
			push @new, $line . "\n";
			push @actual, $line;
		}

		$cmd ||= "GET";

		foreach my $uri ( keys %decoded ) {
			next unless exists $save{ $uri };
			push @used_save, $uri;
			my $save = $save{ $uri };
			if ( not ref $save or ref $save ne "HASH" ) {
				warn "Invalid \$save{ $uri } => $save\n";
				next;
			}
			
			my $options = $decoded{ $uri }->[1];

			$cmd = $save->{cmd} if $save->{cmd};
			hadd $globals, %{$save->{globals}} if $save->{globals};
			hadd $options, %{$save->{options}} if $save->{options};

			if ( my $links = $save->{links} ) {
				push @new, map { "ADD: $_\n" } @$links;
				# don't bother with @actual, list will be reread shortly
				$update = 2;
			}

			if ( my $clones = $save->{clones} ) {
				hadd \%decoded, %{ $clones };
				$update = 2;
			}
			delete $decoded{ $uri } if $save->{delete};
		}

		if ( $process ) {
			&$process( $cmd, $globals, \%decoded );
		}

		foreach my $uri ( keys %decoded ) {
			if ( $all_uri{ $uri } ) {
				warn "URI: $uri repeated, removing second one\n";
				#hadd $options, %{ $all_uri{ $uri }->[1] };
				#$all_uri{ $uri }->[1] = $options;
				delete $decoded{ $uri };
			} else {
				$all_uri{ $uri } = $decoded{ $uri };
			}
		}

		next unless keys %decoded;

		my $all_error = 1;
		foreach my $uri ( keys %decoded ) {
			my $options = $decoded{ $uri }->[1];
			if ( not $options->{error} or $options->{delay} ) {
				$all_error = 0;
				last;
			}
		}
		$cmd = "STOP" if $all_error and $cmd ne "DONE";

		push @actual, {
			cmd => $cmd,
			globals => $globals,
			uris => \%decoded
		};

		{
			my @out = ( "$cmd:", h2a( $globals ) );
			push @new, (join " ", @out) . "\n";
		}
		foreach my $uri ( sort keys %decoded ) {
			my @out = ( $uri, h2a( $decoded{ $uri }->[1] ) );
			push @new, (join " ", '+', @out) . "\n";
		}
	}
	
	# we are forced to regenerate the list if there was something added
	unlink $file_swp if @added or $update == 2;

	unless ( -e $file_swp ) {
		my $fh = list_open $file . ".tmp";
		print $fh @new;
		$fh->flush() or die "Cannot write data to file: $!\n";
		list_close $list_fh;
		unlink $file;
		rename $file . ".tmp", $file;
		$list_fh = $fh;
		@added = ();
		$process = undef;
		foreach my $uri ( @used_save ) {
			delete $save{ $uri };
		}
	}

	$update = $update == 2 ? 1 : 0;
	$listmtime = (stat $file)[9];

	return \@actual;
}

1;

# vim: ts=4:sw=4
