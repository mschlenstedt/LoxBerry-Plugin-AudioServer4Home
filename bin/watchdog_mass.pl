#!/usr/bin/perl

use LoxBerry::System;
use LoxBerry::IO;
use LoxBerry::Log;
use LoxBerry::JSON;
use Getopt::Long;
#use warnings;
#use strict;
#use Data::Dumper;

# Version of this script
my $version = "0.1.0";

# Globals
my $error;
my $verbose;
my $action;

# Logging
my $log = LoxBerry::Log->new (  name => "watchdog",
	package => 'loxbuddy',
	logdir => "$lbplogdir",
	addtime => 1,
);

# Commandline options
GetOptions ('verbose=s' => \$verbose,
            'action=s' => \$action);

# Verbose
if ($verbose) {
        $log->stdout(1);
        $log->loglevel(7);
}

LOGSTART "Starting Watchdog";

# Lock
my $status = LoxBerry::System::lock(lockfile => 'loxbuddy-watchdog', wait => 10);
if ($status) {
	LOGCRIT "$status currently running - Quitting.";
	exit (1);
}

# Creating tmp file with failed checks
my $response;
if (!-e "/dev/shm/loxbuddy-watchdog-fails.dat") {
	$response = LoxBerry::System::write_file("/dev/shm/loxbuddy-watchdog-fails.dat", "0");
}

# Todo
if ( $action eq "start" ) {

	&start();

}

elsif ( $action eq "stop" ) {

	&stop();

}

elsif ( $action eq "restart" ) {

	&restart();

}

elsif ( $action eq "check" ) {

	&check();

}

else {

	LOGERR "No valid action specified. --action=start|stop|restart|check is required. Exiting.";
	print "No valid action specified. --action=start|stop|restart|check is required. Exiting.\n";
	exit(1);

}

exit (0);


#############################################################################
# Sub routines
#############################################################################

##
## Start
##
sub start
{
	# Start with:
	#   - npx vite --host
	#   - node /opt/loxberry/bin/plugins/loxbuddy/loxbuddy/node_modules/.bin/vite --host
	if (-e  "$lbpconfigdir/stopped.cfg") {
		unlink("$lbpconfigdir/stopped.cfg");
	}

	my $count = `pgrep -c -f "loxbuddy/node_modules/.bin/vite"`;
	chomp ($count);
	$count--; # Perl itself runs pgrep with sh, which also match -f in pgrep
	if ($count > "0") {
		LOGCRIT "LoxBuddy App already running. Please stop it before starting again. Exiting.";
		exit (1);
	}

	LOGINF "Checking configuration...";
	if ($verbose) {
		system("$lbpbindir/create_config.pl --verbose=1 > /dev/null 2>&1")
	} else {
		system("$lbpbindir/create_config.pl > /dev/null 2>&1")
	}

	LOGINF "Starting LoxBuddy...";

	my $child_pid = fork();
	die "Couldn't fork" unless defined $child_pid;
	if (! $child_pid) {
		exec "cd $lbpbindir/loxbuddy && node /opt/loxberry/bin/plugins/loxbuddy/loxbuddy/node_modules/.bin/vite --host > /dev/null 2>&1 &";
		die "Couldn't exec my program: $!";
	}

	sleep 2;

	$count = `pgrep -c -f "loxbuddy/node_modules/.bin/vite"`;
	chomp ($count);
	$count--; # Perl itself runs pgrep with sh, which also match -f in pgrep
	if ($count eq "0") {
		LOGCRIT "Could not start LoxBuddy. Error: $?";
		exit (1)
	} else {
		my $status = `pgrep -o -f "loxbuddy/node_modules/.bin/vite"`;
		chomp ($status);
		LOGOK "LoxBuddy started successfully. Running PID: $status";
	}

	return (0);

}

sub stop
{

	$response = LoxBerry::System::write_file("$lbpconfigdir/stopped.cfg", "1");

	LOGINF "Stopping LoxBuddy...";
	system ("pkill -f 'loxbuddy/node_modules/.bin/vite' > /dev/null 2>&1");
	sleep 2;

	my $count = `pgrep -c -f "loxbuddy/node_modules/.bin/vite"`;
	chomp ($count);
	$count--; # Perl `` itself runs pgrep with sh, which also match -f in pgrep
	if ($count eq "0") {
		LOGOK "LoxBuddy stopped successfully.";
	} else {
		my $status = `pgrep -o -f "loxbuddy/node_modules/.bin/vite"`;
		chomp ($status);
		LOGCRIT "Could not stop LoxBuddy. Still Running PID: $status";
		exit (1)
	}

	return(0);

}

sub restart
{

	$log->default;
	LOGINF "Restarting LoxBuddy...";
	&stop();
	sleep (2);
	&start();

	return(0);

}

sub check
{

	LOGINF "Checking Status of LoxBuddy...";

	if (-e  "$lbpconfigdir/stopped.cfg") {
		LOGOK "LoxBuddy was stopped manually. Nothing to do.";
		return(0);
	}

	my $count = `pgrep -c -f "loxbuddy/node_modules/.bin/vite"`;
	chomp ($count);
	$count--; # Perl `` itself runs pgrep with sh, which also match -f in pgrep
	if ($count eq "0") {
		LOGERR "LoxBuddy seems not to be running.";
		my $fails = LoxBerry::System::read_file("/dev/shm/loxbuddy-watchdog-fails.dat");
		chomp ($fails);
		$fails++;
		if ($fails > 9) {
			LOGERR "Too many failures. Will stop watchdogging... Check your configuration and start service manually.";
		} else {
			my $response = LoxBerry::System::write_file("/dev/shm/loxbuddy-watchdog-fails.dat", "$fails");
			&restart();
		}
	} else {
		my $status = `pgrep -o -f "loxbuddy/node_modules/.bin/vite"`;
		chomp ($status);
		LOGOK "LoxBuddy is running. Fine. Running PID: $status";
		my $response = LoxBerry::System::write_file("/dev/shm/loxbuddy-watchdog-fails.dat", "0");
	}

	return(0);

}

##
## Always execute when Script ends
##
END {

	LOGEND "This is the end - My only friend, the end...";
	LoxBerry::System::unlock(lockfile => 'loxbuddy-watchdog');

}
