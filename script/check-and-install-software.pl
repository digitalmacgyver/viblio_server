#!/usr/bin/env perl
#
# This script is used to update Viblio software on a running machine.
# It returns 0 if no software was installed, 1 if software was installed,
# and 2 if there was a script error.  It writes to syslog (so loggly has it)
# if there was a script error.
#
use strict;
use YAML;
use DBI;
use JSON;
use Try::Tiny;
use Logger::Syslog;
use Data::Dumper;

my $Usage = "$0 -db <staging|prod> -app <app> [-c config] [-force]";

my( $dbname, $app, $config, $force );

# Default config file.  This is a YAML syntax file, and contains
# the database connection info, as well as application info such
# as the currently installed version of the app.
$config = "/etc/viblio.yml";
$force = 0;

# Parse the args
my $command_line = join( ' ', @ARGV );
while( my $arg = shift( @ARGV ) ) {
    if ( $arg eq '-db' ) {
	$dbname = shift @ARGV; next;
    }
    if ( $arg eq '-app' ) {
	$app = shift @ARGV; next;
    }
    if ( $arg eq '-c' ) {
	$config = shift @ARGV; next;
    }
    if ( $arg eq '-force' ) {
	$force = 1; next;
    }
}

unless( $dbname && $app && $config ) {
    error( "Bad command line: $command_line" );
    print $Usage,"\n";
    exit 2;
}

# Read the config
my $cfg;
try {
    $cfg = YAML::LoadFile( $config );
} catch {
    error( $_ );
    print $_,"\n";
    exit 2;
};

# If we're forcing an install ...
$cfg->{$app}->{version} = 'forced';

# Open the database
unless( $cfg && $cfg->{db} && $cfg->{db}->{$dbname} ) {
    error( "Cannot find database connection info for '$dbname'" );
    print "Cannot find database connection info for '$dbname'", "\n";
    exit 2;
}

my $db = DBI->connect( 'DBI:mysql:database=' . 
		       $cfg->{db}->{$dbname}->{database} .
		       ';host=' . $cfg->{db}->{$dbname}->{host},
		       $cfg->{db}->{$dbname}->{user},
		       $cfg->{db}->{$dbname}->{password} );
unless( $db ) {
    error( "Could not connect to $dbname" );
    print "Could not connect to $dbname\n";
    exit 2;
}

# Obtain information about the app
my( $version, $json );
try {
    my $sth = $db->prepare( "select version_string, config from app_configs where app = '$app' and current=1" );
    $sth->execute;
    my $ref = $sth->fetchrow_hashref();
    $version = $ref->{version_string};
    $json = $ref->{config}
} catch {
    my $err = $_;
    error( "Failed to obtain version_string and config for $app" );
    print $err, "\n";
    exit 2;
};

# Compare the version from the database against the version
# we think we have locally.  All we do is a diff, nothing fancy.
# If there is not a match, then we're gonna download and install
#
my $install = 1;
if ( $cfg->{$app} && $cfg->{$app}->{version} &&
     ( $cfg->{$app}->{version} eq $version ) ) {
    $install = 0;
}
unless( $install ) {
    print "Nothing to install: $app local version $version is same as released version $cfg->{$app}->{version}\n";
    exit 0;
}

info( "Installing new $app because local version $version does not match released version " . ( $cfg->{$app}->{version} || 'unknown' ) );
print "Installing new $app because local version $version does not match released version " . ( $cfg->{$app}->{version} || 'unknown' ), "\n";

# Ok, we are installing.  Parse the app config (json).
my $hash = from_json( $json );
print Dumper $hash;

# Download the image into a temporary directory and untar it

# If it has a Makefile, execute it

# Or if it has an executable 'runme', then run it

# If we get here, the installation is finished and is successful.
# Clean up the temporary directory ...

# And then commit the newest version to our local config
try {
    $cfg->{$app}->{version} = $version;
    YAML::DumpFile( $config, $cfg );
} catch {
    error( "Failed to commit $app new version $version into $config" );
    print "Failed to commit $app new version $version into $config\n";
    exit 2;
};

# and we're done.  exit 1 means to the outside world that new
# software was installed.
exit 1;
