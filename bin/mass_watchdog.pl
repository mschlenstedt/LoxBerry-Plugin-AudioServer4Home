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
my $log = LoxBerry::Log->new (  name => "mass_watchdog",
	package => 'musicserver4home-ng',
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

LOGSTART "Starting Mass Watchdog";

# Lock
my $status = LoxBerry::System::lock(lockfile => 'mass-watchdog', wait => 10);
if ($status) {
	LOGCRIT "$status currently running - Quitting.";
	exit (1);
}

# Creating tmp file with failed checks
my $response;
if (!-e "/dev/shm/mass-watchdog-fails.dat") {
	$response = LoxBerry::System::write_file("/dev/shm/mass-watchdog-fails.dat", "0");
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
	if (-e  "$lbpconfigdir/mass_stopped.cfg") {
		unlink("$lbpconfigdir/mass_stopped.cfg");
	}

	my $count = `sudo docker ps | grep -c musicassistent`;
	chomp ($count);
	if ($count > "0") {
		LOGCRIT "Music Assistent already running. Please stop it before starting again. Exiting.";
		exit (1);
	}

	LOGINF "Starting Music Assistent...";

	#my $child_pid = fork();
	#die "Couldn't fork" unless defined $child_pid;
	#if (! $child_pid) {
	#	exec "sudo docker run -v test:/data --name musicassistent --network host --cap-add=DAC_READ_SEARCH --cap-add=SYS_ADMIN --security-opt apparmor:unconfined ghcr.io/music-assistant/server:$release > /dev/null 2>&1 &";
	#	die "Couldn't exec Music Assistent: $!";
	#}
	my $output = `sudo docker run -v $lbpplugindir:/data --detach --name musicassistent --network host --cap-add=DAC_READ_SEARCH --cap-add=SYS_ADMIN --security-opt apparmor:unconfined ghcr.io/music-assistant/server:latest 2>&1`;
	chomp ($output);

	my $count = `sudo docker ps | grep -c musicassistent`;
	chomp ($count);
	if ($count eq "0") {
		LOGCRIT "Could not start Music Assistent - Error: $output";
		exit (1)
	} else {
		my $id = `sudo docker ps | grep musicassistent | awk '{ print \$1 }'`;
		chomp ($id);
		LOGOK "LoxBuddy started successfully. Container ID: $id";
	}

	return (0);

}

sub stop
{

	$response = LoxBerry::System::write_file("$lbpconfigdir/mass_stopped.cfg", "1");

	LOGINF "Stopping Music Assistent...";
	my $output = `sudo docker stop musicassistent 2>&1`;
	$output .= `sudo docker rm musicassistent 2>&1`;
	chomp ($output);

	my $count = `sudo docker ps | grep -c musicassistent`;
	chomp ($count);
	if ($count eq "0") {
		LOGOK "Music Assistent stopped successfully.";
	} else {
		my $id = `sudo docker ps | grep musicassistent | awk '{ print \$1 }'`;
		chomp ($id);
		LOGCRIT "Could not stop Music Assistent - Error: $output. Still Running ID: $id";
		exit (1)
	}

	return(0);

}

sub restart
{

	$log->default;
	LOGINF "Restarting Music Assistent...";
	&stop();
	&start();

	return(0);

}

sub check
{

	LOGINF "Checking Status of Music Assistent...";

	if (-e  "$lbpconfigdir/mass_stopped.cfg") {
		LOGOK "Music Assistent was stopped manually. Nothing to do.";
		return(0);
	}

	my $count = `sudo docker ps | grep -c musicassistent`;
	chomp ($count);
	if ($count eq "0") {
		LOGERR "Music Assistent seems not to be running.";
		my $fails = LoxBerry::System::read_file("/dev/shm/mass-watchdog-fails.dat");
		chomp ($fails);
		$fails++;
		if ($fails > 9) {
			LOGERR "Too many failures. Will stop watchdogging... Check your configuration and start service manually.";
		} else {
			my $response = LoxBerry::System::write_file("/dev/shm/mass-watchdog-fails.dat", "$fails");
			&restart();
		}
	} else {
		my $id = `sudo docker ps | grep musicassistent | awk '{ print \$1 }'`;
		chomp ($id);
		LOGOK "Music Assistent is running. Fine. ID: $id";
		my $response = LoxBerry::System::write_file("/dev/shm/mass-watchdog-fails.dat", "0");
	}

	return(0);

}

##
## Always execute when Script ends
##
END {

	LOGEND "This is the end - My only friend, the end...";
	LoxBerry::System::unlock(lockfile => 'mass-watchdog');

}
