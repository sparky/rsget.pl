package RSGet::Line;
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
	logfile => {
		desc => "Select log file, empty value disables logging.",
		type => "PATH",
	},
);
my $term_size_columns;
my $term_size_rows;

my %color_to_term = (
	red => 31,
	green => 32,
	yellow => 33,
	orange => 33,
	blue => 34,
	magenta => 35,
	cyan => 36,
	bold => 1,
	"" => 0,
);
sub color_term
{
	my $color = shift || "";
	return "\033[" . $color_to_term{$color} . "m";
}

sub term_size
{
	local $SIG{__DIE__};
	delete $SIG{__DIE__};
	eval {
		require Term::Size;
		( $term_size_columns, $term_size_rows ) = Term::Size::chars();
	};
	$term_size_columns ||= $ENV{COLUMNS} || 80;
	$term_size_rows ||= $ENV{LINES} || 0;

	return $term_size_columns;
}

my $nooutput = 0;
our %active;
my %dead;
our @dead;
our $dead_change = 0;
our %status;
my $log_fh;
my $last_line = 0;

my $last_day = -1;
sub print_dead_lines
{
	my @l = localtime;
	my $time = sprintf "[%.2d:%.2d:%.2d] ", @l[(2,1,0)];

	my @print;
	my @newdead;

	my $endcolor = color_term();
	if ( $last_day != $l[3] ) {
		$last_day = $l[3];
		my $date = sprintf "[Current date: %d-%.2d-%.2d]", $l[5] + 1900, $l[4] + 1, $l[3];
		push @print, "\r" . color_term( "green" ) . $date . $endcolor . "\033[J\n";
		push @newdead, [ $date, "green" ];
	}

	foreach my $key ( sort { $a <=> $b } keys %dead ) {
		my ( $text, $color ) = @{ $dead{$key} };
		$text = $time . $text if $text =~ /\S/;

		push @print, "\r" . color_term( $color ) . $text . $endcolor . "\033[J\n";
		push @newdead, [ $text, $color ];
	}

	print @print unless $nooutput;
	print $log_fh join "\n", @newdead, ''
		if $log_fh;
	if ( @newdead ) {
		push @dead, @newdead;
		$dead_change++;

		my $max = 1000;
		if ( scalar @dead > $max ) {
			splice @dead, 0, $max - scalar @dead;
		}
	}

	%dead = ();
}

sub print_status_lines
{
    my $columns = shift();
	my $horiz = "-" x ($columns - 4);

	my $date = "< ".isotime()." >";
	my $date_l = length $date;
	my $h = $horiz;
	substr $h, int( (length($horiz) - $date_l ) / 2 ), $date_l, $date;

	my @status = ( "rsget.pl -- " );
	foreach my $name ( sort keys %status ) {
		my $value = $status{$name};
		next unless $value;
		my $s = "$name: $value; ";
		if ( length $status[ $#status ] . $s > $columns - 5 ) {
			push @status, $s;
		} else {
			$status[ $#status ] .= $s;
		}
	}

	my $endcolor = color_term();
	my $bold = color_term( "bold" );

	my @print = ( " $bold\\$h/$endcolor" );
	foreach ( @status ) {
		my $l = " $bold|$endcolor" . ( " " x ($columns - 4 - length $_ )) . $_ . "$bold|$endcolor";
		push @print, $l;
	}
	push @print, " $bold/$horiz\\$endcolor";
	print map { "\r\n$_\033[K" } @print;
	return scalar @print;
}


sub print_active_lines
{
    my $columns = shift() - 1;
	my @print;

	my $endcolor = color_term();
	foreach my $key ( sort { $a <=> $b } keys %active ) {
		my $line = $active{$key};

		my $text = $line->[1];
		my $tl = length $line->[0] . $text;
		substr $text, 4, $tl - $columns + 3, '...'
			if $tl > $columns;
		push @print, "\r\n\033[K" . color_term( $line->[3] ) . $line->[0] . $text . $endcolor;
	}

	print @print;
	return scalar @print;
}

sub print_all_lines
{
	print_dead_lines();
	return if $nooutput;
	term_size() unless $term_size_columns;
	my $added = 0;
	$added += print_status_lines( $term_size_columns );
	$added += print_active_lines( $term_size_columns );
	return $added;
}

sub update
{
	my $added = print_all_lines();
	return if $nooutput;
	print "\033[J\033[" . $added . "A\r" if $added;
}

sub new
{
    my $class = shift;
	my $head = shift;
	my $text = shift;
	my $assoc = shift;
	my $color = shift;
	$head = "" unless defined $head;

	my $line = "" . ($last_line++);
	$active{ $line } = [ $head, "", $assoc, $color ];

	my $self = \$line;
	bless $self, $class;
	$self->print( $text );

	return $self;
}

sub print
{
	my $self = shift;
	my $line = $$self;
	my $text = shift;
	$text = "" unless defined $text;
	$text =~ s/\n+$//sg;
	$text =~ s/\n/ /sg;
	$text =~ s/\0/***/g;
	$active{ $line }->[1] = $text;

	return length $text;
}

sub linedata
{
	my $self = shift;
	my $data = shift;
	$active{ $$self }->[2] = $data;
}

sub color
{
	my $self = shift;
	my $color = shift;
	$active{ $$self }->[3] = $color;
}

sub clone
{
	my $self = shift;
	my $line = $$self;
	return new RSGet::Line @{ $active{ $line } };
}

sub DESTROY
{
	my $self = shift;
	my $line = $$self;
	my $l = $active{ $line };
	$dead{ $line } = [ $l->[0] . $l->[1], $l->[3] ];
	delete $active{ $line };
}

sub status
{
	hadd( %status, @_ );
}

END {
	close $log_fh if $log_fh;
}

sub init
{
	$nooutput = shift;
	$| = 1;

	if ( my $file = setting( "logfile" ) ) {
		$log_fh = undef;
		open $log_fh, ">>", $file
			or die "Cannot open log file $file: $!\n";
	}

	$SIG{__WARN__} = sub {
		RSGet::Line->new( "WARNING: ", shift, undef, "orange" );
		update();
	};

	return if $nooutput;

	$SIG{WINCH} = sub {
		print "\033[2J\033[1;1H\n";
		term_size();
		my $start = $term_size_rows ? $#dead - $term_size_rows : 0;
		$start = 0 if $start < 0;
		print join( "\n", @dead[($start..$#dead)] ), "\n";
		update();
	};

	$SIG{__DIE__} = sub {
		print_all_lines();
		print "\n\nDIED: ", shift, "\n\n";
		exit 1;
	};
}

1;

# vim: ts=4:sw=4
