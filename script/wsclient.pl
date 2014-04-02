#!/usr/bin/env perl
#
# A flexible command line client to call web service methods.
#
use strict;
use lib "lib";
use WSClient;
use Getopt::Long;
use Data::Dumper;

my $Usage = <<_EOU;
$0 [connection options] [service] -- [service options]
(options shown with defaults)

--quiet    (default will print result on screen)
--no-redirects (default will follow redirects)
--url=http://localhost
--port=80
--user=    (no default, user name to connect as)
--pass=    (no default, password for user, prompted for if not supplied)
--service= (default is the base service, informational)
--upload=filename (will do a file upload)
--download=filename (will do a file download)
--method=  post, get, put: default is get
--dump-request
--dump-response
--server-debug (Sends X-Debug header)
--expect=(accept header string, i.e. application/json, text/javascript)
--xhr (send X-Requested-With: XMLHttpRequest)
[arg1=val1 [arg2=val2 ...]] arguments to service

Example:

$0 --port=3000 --user=joe --pass=blow \\
  --service=add_user -- username=sally password=paswd fullname='Sally Field'
_EOU

my $url = "http://localhost";
my $port = 80;
my ($user, $pass);
my $service = "";
my $quiet = 0;
my ( $upfilename, $downfilename );
my $use_cookies = 1;
my @args;
my $method = 'get';
my( $dump_req, $dump_res ) = ( 0, 0 );
my $server_debug = 0;
my $xhr = 0;
my $expect = undef;
my $no_redirects = 0;
my $result = GetOptions
    ( "url=s" => \$url,
      "port=i" => \$port,
      "username=s" => \$user,
      "password=s" => \$pass,
      "service=s", => \$service,
      "quiet" => \$quiet,
      "use-cookies" => \$use_cookies,
      "upload=s" => \$upfilename,
      "download=s" => \$downfilename,
      "help", sub { print $Usage; exit 0; },
      "method=s" => \$method,
      "dump-request" => \$dump_req,
      "dump-response" => \$dump_res,
      "server-debug" => \$server_debug,
      "xhr" => \$xhr,
      "expect=s" => \$expect,
      "no-redirects" => \$no_redirects,
    );

exit 1 unless( $result );

# Grab any service args
while (( my $arg = shift @ARGV )) {
    my( $k, $v ) = split( /=/, $arg, 2 );
    if ( $k && defined($v) ) {
	if ( $k =~ /\[\]$/ ) {
	    my @v = split(/,/,$v);
	    $v = \@v;
	}
	push( @args, $k => $v );
    }
}


#unless( $user ) {
#    die "Must specify --username for authentication!";
#}

if ( $user && ! $pass ) {
    eval "use Term::ReadKey";
    if ( $@ ) {
	die "To use password prompt, please install Term::ReadKey.";
    }
    my( $pw1, $pw2 );

    print "password: ";
    ReadMode('noecho');
    $pw1 = ReadLine(0);
    chomp $pw1;

    print "\n";

    print "confirm password: ";
    ReadMode('noecho');
    $pw2 = ReadLine(0);
    chomp $pw2;

    ReadMode(0);
    print "\n";

    die "Passwords don't match! User not created!\n" unless( $pw1 eq $pw2 );
    $pass = $pw1;
}

my $ws = new WSClient root_url=>"$url:$port", base_url=>"$url:$port", 
    dump_request=>$dump_req, dump_response=>$dump_res,
    expect => $expect, debug => $server_debug, xhr => $xhr,
    no_redirects => $no_redirects,
    email=>$user, password=>$pass, use_cookies=>$use_cookies;

die "Could not connect to server at $url:$port!"
    unless( $ws );

if ( $upfilename && ! -f $upfilename ) {
    die "You specified a file to upload, but I cannot find it!";
}

my $data;
if ( $upfilename && -f $upfilename ) {
    $data = $ws->upload( $service, $upfilename, @args );
}
elsif ( $downfilename ) {
    $data = $ws->download( $service, $downfilename, @args );
}
else {
    if ( $method eq 'post' ) {
	$data = $ws->post( $service, @args );
    }
    elsif ( $method eq 'get' ) {
	$data = $ws->get( $service, @args );
    }
    elsif ( $method eq 'put' ) {
	$data = $ws->put( $service, @args );
    }
}
print Dumper $data unless( $quiet );

if ( $data && $data->{iserror} ) {
    exit 1;
}
else {
    exit 0;
}
