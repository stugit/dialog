#!/bin/env perl
use strict;
use warnings;

use 5.16.3;

use Getopt::Long;
use Config::IniFiles;
use Logger;
use Data::Dumper;
use  Term::ANSIColor qw/:constants/;
use sigtrap qw/handler signal_handler normal-signals stack-trace any error-signals/;

# global vars
my $date = `date '+%a %d %h %Y %R'`;
chomp($date);
my $hostname = `hostname`;
chomp($hostname);
my $tmp = "/tmp/dialog.selection.$$.txt";
my $output = "/tmp/dialog.output.$$.txt";
local $Term::ANSIColor::AUTORESET = 1;

my $log = Logger->new(loglevel => 'debug');

# Defaults
my  %options = ();

GetOptions(\%options,
	"config=s",
	"loglevel=s",
);

$log->loglevel($options{loglevel}) if $options{loglevel};
if (not $options{config}) {
	$log->fatal("--config is mandatory.");
	exit 1;
}

my $cfg = Config::IniFiles->new( -file => $options{config} ) or do {
	$log->fatal('Problem creating config object.');
	exit 1;
};

# Let's display the main menu
dialog( section => 'mainmenu' );
tidyup();

exit 0;

sub lpad {
	my $str = shift;
	my $len = shift;
	my $c = shift // ' ';

	return $c x ($len - length($str)) . $str;
}

sub rpad {
	my $str = shift;
	my $len = shift;
	my $c = shift // ' ';

	return $str . $c x ($len - length($str));
}

sub dialog {
	my %args = @_;

	my $section = $args{section};
	$log->debug("section: " . $section);

	if ($cfg->val($section, 'type') =~ m/^menu/i ) {
		 dialog_menu( section => $section );
	}
	elsif ($cfg->val($section, 'type') =~ m/^msgbox/i ) {
		dialog_msgbox( section => $section );
	}
	elsif ($cfg->val($section, 'type') =~ m/^command/i ) {
		$log->debug("executing command: " . $cfg->val($section, 'command'));
		#system($cfg->val($section, 'command'));
		exec($cfg->val($section, 'command'));
	}
}

# 
# args
# input: 
#
sub dialog_menu {
	my %args = @_;
	
	my $section = $args{section};

	my $cmd = "dialog ";
	$cmd .= "--backtitle \'" . backtitle(title => $cfg->val($section, 'title')) . "\' ";
	$cmd .= "--clear ";
	$cmd .= "--nocancel ";
	$cmd .= "--menu 'Please select one:' ";
	$cmd .= $cfg->val($section, 'height');
	$cmd .= ' ';
	$cmd .= $cfg->val($section, 'width');
	$cmd .= ' ';
	$cmd .= $cfg->val($section, 'menu_height');
	$cmd .= ' ';

	my @options = $cfg->val($section, 'option');
	$log->debug('options: ' . Dumper(\@options));

    my %menu = ();
    foreach my $opt (@options) {
		my @opt = split(/,/, $opt);
		$log->debug(Dumper(\@opt));
		$cmd .= $opt[0] . ' ';
		my ($idx, $dummy) = split(/ /, $opt[0]);
		$menu{$idx} = $opt[1];
	}
	

	$cmd .= "2>$tmp";
	$log->debug("cmd: " . $cmd);
	my $rc = undef;
	while ($rc = system($cmd) == 256) {};
	$log->debug("rc: " . $rc);
	my $selection = slurp($tmp);

	my %results = ();
	$results{rc} = $rc;
	$results{selection} = $selection;

	$log->debug("menu: " . Dumper(\%menu));
	$log->debug("selection: $selection");
	if ( $selection ) {
		dialog(section => $menu{$selection});
    }
    else {
		if ($section eq 'mainmenu') {
			exit;
		}
		else {
			dialog(section => $cfg->val($section, 'previous_section' ));
		}
	}
}

sub dialog_msgbox {
	my %args = @_;
	
	my $section = $args{section};
	my $text = "";

	if ($cfg->val($section, 'command')) {
		system($cfg->val($section, 'command') . ' > ' . $output );
		$text = slurp($output );		
	}
	elsif ($cfg->val($section, 'message')) {
		$text = $cfg->val($section, 'message');
	}

	my $cmd = "dialog ";
	if ($cfg->val($section, 'backtitle')) {
		$cmd .= "--backtitle \"" . $cfg->val($section, 'backtitle') . "\" ";
	}
	$cmd .= "--title " . $cfg->val($section, 'title') . " ";
	$cmd .= "--clear ";
	$cmd .= "--msgbox '" . $text . "' ";
	$cmd .= $cfg->val($section, 'height') . ' ';
	$cmd .= $cfg->val($section, 'width') . ' ';
	$log->debug("cmd: " . $cmd);
	system($cmd);
	dialog(section => $cfg->val($section, 'previous_section'));
}

# TODO handle control-z
sub signal_handler {
	$log->debug("Handled interrupt ($!)");
	tidyup();
}

sub tidyup {
	if ( -e $tmp ) {
		$log->debug("Deleting tmp file $tmp");
		$log->debug("contents: " . `cat $tmp`);
		unlink($tmp);
	}
}

sub slurp {
    my $file = shift;
    open my $fh, '<', $file or die;
    local $/ = undef;
    my $cont = <$fh>;
    close $fh;
    return $cont;
}

sub number_cols {
	return `tput cols`;
}

sub number_lines {
	return `tput lines`;
}

sub backtitle {
	my %args = @_;
	my $btitle = $args{backtitle};

	my $backtitle = $hostname;
	$backtitle .= ' ';
	$backtitle .= lpad('', number_cols()
		- length($hostname) 		
		- length($btitle) - 5 - length($date), ' ');
	$backtitle .= $btitle;
	$backtitle .= '  ';
	$backtitle .= $date;
	return $backtitle;
}
