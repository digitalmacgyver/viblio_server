#!/usr/bin/env perl
#
# This script is used to update Viblio software on a running machine.
# It returns 0 if no software was installed, 1 if software was installed.
# It writes to syslog (so loggly has it) if there was a script error.
#
use strict;
use YAML;
use DBI;
use JSON;
use Try::Tiny;
use Data::Dumper;
use File::Temp qw/ tempfile tempdir /;
use Net::Amazon::S3;
use Net::Amazon::S3::Client;
use File::Basename;

BEGIN {
    # The way Logger::Syslog dumps app name and the way loggly wants
    # to see it are different, so ...
    $ENV{'MOD_PERL'} = 1;
    $ENV{'SCRIPT_FILENAME'} = 'check-and-install-software';
    use Logger::Syslog;
    logger_init();
}

my $Usage = "$0 -db <staging|prod> -app <app> [-c config] [-quiet] [-force] [-check]";

my( $dbname, $app, $config, $force, $check, $quiet );

# Default config file.  This is a YAML syntax file, and contains
# the database connection info, as well as application info such
# as the currently installed version of the app.
$config = "/etc/viblio.yml";
$force = 0;
$check = 0;
$quiet = 0;

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
    if ( $arg eq '-check' ) {
	$check = 1; next;
    }
    if ( $arg eq '-quiet' ) {
	$quiet = 1; next;
    }
}

unless( $dbname && $app && $config ) {
    error( "Bad command line: $command_line" );
    print $Usage,"\n";
    exit 0;
}

# Pre-append the $app to all messages
logger_prefix( $app );
# Make sure after our twidling that the stack gets reported correctly
undef $ENV{'MOD_PERL'};

# Read the config
my $cfg;
try {
    $cfg = YAML::LoadFile( $config );
} catch {
    error( $_ );
    print $_,"\n" unless( $quiet );
    exit 0;
};

# If we're forcing an install ...
$cfg->{$app}->{version} = 'forced';

# Open the database
unless( $cfg && $cfg->{db} && $cfg->{db}->{$dbname} ) {
    error( "Cannot find database connection info for '$dbname'" );
    print "Cannot find database connection info for '$dbname'", "\n" unless( $quiet );
    exit 0;
}

my $db = DBI->connect( 'DBI:mysql:database=' . 
		       $cfg->{db}->{$dbname}->{database} .
		       ';host=' . $cfg->{db}->{$dbname}->{host},
		       $cfg->{db}->{$dbname}->{user},
		       $cfg->{db}->{$dbname}->{password} );
unless( $db ) {
    error( "Could not connect to $dbname" );
    print "Could not connect to $dbname\n" unless( $quiet );
    exit 0;
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
    print $err, "\n" unless( $quiet );
    exit 0;
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
    print "Nothing to install: $app local version $version is same as released version $cfg->{$app}->{version}\n" unless( $quiet );
    exit 0;
}

# If we are just checking ...
if ( $check ) {
    exit 1;
}

info( "Installing new $app because local version $version does not match released version " . ( $cfg->{$app}->{version} || 'unknown' ) );
print "Installing new $app because local version $version does not match released version " . ( $cfg->{$app}->{version} || 'unknown' ), "\n" unless( $quiet );

# Ok, we are installing.  Parse the app config (json).
my $hash = from_json( $json );

# Download the image into a temporary directory and untar it
my $tmpdir = tempdir( CLEANUP => 1 );
## The uri in the config struct is of the form:
## bucket/key
my $filename = basename( $hash->{uri} );
my @parts = split( /\//, $hash->{uri} );
my $bucket = shift @parts;
my $key = join( '/', @parts );

try {
    my $s3 = Net::Amazon::S3->new(
	aws_access_key_id => $cfg->{s3}->{key},
	aws_secret_access_key => $cfg->{s3}->{secret},
	retry => 1 );
    my $client = Net::Amazon::S3::Client->new( s3 => $s3 );
    my $bucket = $client->bucket( name => $bucket );
    my $object = $bucket->object( key => $key );
    print "Downloading $key into $tmpdir/$filename ...\n" unless( $quiet );
    $object->get_filename( "$tmpdir/$filename" );
    # system( "ls -l $tmpdir/$filename" );
} catch {
    error( "$app: Failed to download $key from S3" );
    print $_, "\n" unless( $quiet );
    exit 0;
};

my $unpack = "unzip";
if ( $filename =~ /\.tar.gz/ ) {
    $unpack = "tar zxf";
}
if ( system( "cd $tmpdir; $unpack $filename >/dev/null 2>&1 " ) ) {
    error( "Failed to unpack image for $app: $_" );
    print "$_\n" unless( $quiet );
    exit 0;
}
# system( "cd $tmpdir; ls -l" );

# If it has a Makefile, execute it
if ( -f "$tmpdir/Makefile" ) {
    if ( system( "cd $tmpdir; make LVL=$dbname APP=$app install" ) ) {
	error( "Failed to run package make for $app: $_" );
	print "Failed to run package make for $app: $_\n" unless( $quiet );
	exit 0;
    }
}
elsif ( -x "$tmpdir/runme" ) {
  # Or if it has an executable 'runme', then run it
    if ( system( "cd $tmpdir; ./runme -lvl $dbname -app $app -install" ) ) {
	error( "Failed to run package runme for $app: $_" );
	print "Failed to run package runme for $app: $_\n" unless( $quiet );
	exit 0;
    }
}
else {
    error( "Package does not include a Makefile or a runme for installation" );
    print "Package does not include a Makefile or a runme for installation\n" unless( $quiet );
    exit 0;
}

# If we get here, the installation is finished and is successful.
# Clean up the temporary directory ...

# And then commit the newest version to our local config
try {
    $cfg->{$app}->{version} = $version;
    YAML::DumpFile( $config, $cfg );
} catch {
    error( "Failed to commit $app new version $version into $config" );
    print "Failed to commit $app new version $version into $config\n" unless( $quiet );
    exit 0;
};

# and we're done.  exit 1 means to the outside world that new
# software was installed.
exit 1;
