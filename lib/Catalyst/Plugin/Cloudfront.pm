package Catalyst::Plugin::Cloudfront;
use strict;
use warnings;

# Utility functions that get attached to $c

use Class::C3;
use Set::Object         ();
use Scalar::Util        ();
use Catalyst::Exception ();

#use File::Temp qw/tempfile/;
#use Getopt::Long;
use IPC::Open2;
use MIME::Base64 qw(encode_base64 decode_base64);
use URI;
use DateTime;
use Crypt::OpenSSL::RSA;

my $CANNED_POLICY 
    = '{"Statement":[{"Resource":"<RESOURCE>","Condition":{"DateLessThan":{"AWS:EpochTime":<EXPIRES>}}}]}';

my $POLICY_PARAM      = "Policy";
my $EXPIRES_PARAM     = "Expires";
my $SIGNATURE_PARAM   = "Signature";
my $KEY_PAIR_ID_PARAM = "Key-Pair-Id";

my $rsa_priv;

# cf_sign - Create signed Cloudfront URLS
#
# Usage:
# $c->cf_sign( 'test/test.mp4' [, {options} ] )
#
# options = {
#   stream  => 0      ** 0 for web downloads, 1 for flowplayer streams
#   expires => 60*30  ** in 30 minutes from now 
#   policy  => JSON policy statement (the default is probably sufficient)
# }
#
sub cf_sign {
    my( $c, $uri, $options ) = @_;
    $options = {} unless( $options );
    $options->{stream} = 0 unless( $options->{stream} );
    $options->{policy} = $CANNED_POLICY unless( $options->{policy} );
    $options->{expires} = (60 * 30) unless( $options->{expires} ); # 30 minute default

    my $verbose = 0;
    my $policy_filename = "";
    my $expires_epoch = 0;
    my $action = "";
    my $url = "";
    my $stream = "";

    my $key_pair_id = $c->config->{cloudfront}->{keypairid};
    my $private_key_filename = $c->path_to('lib', 'cloudfront', 'key-pairs', 'pk-APKAIT7GXEAJMNP76GCQ.pem' );

    unless( $rsa_priv ) {
	my $key_string = read_file( $private_key_filename );
	$rsa_priv = Crypt::OpenSSL::RSA->new_private_key($key_string);
    }

    if ( $options->{stream} ) {
	$stream = $uri;
    }
    else {
	$url = 'https://' . $c->config->{cloudfront}->{web_domain} . '/' . $uri;
    }
    $action = "encode";
    my $now = DateTime->now->epoch;
    $expires_epoch = $now + $options->{expires};


    if ($url eq "" and $stream eq "") {
	print STDERR "Must include a stream or a URL to encode or decode with the --stream or --url option\n";
	exit;
    }

    if ($url ne "" and $stream ne "") {
	print STDERR "Only one of --url and --stream may be specified\n";
	exit;
    }

    if ($url ne "" and !is_url_valid($url)) {
	exit;
    }

    if ($stream ne "") {
	exit unless is_stream_valid($stream);

	# The signing mechanism is identical, so from here on just pretend we're
	# dealing with a URL
	$url = $stream;
    } 

    if ($action eq "encode") {
	# The encode action will generate a private content URL given a base URL, 
	# a policy file (or an expires timestamp) and a key pair id parameter
	my $private_key;
	my $public_key;
	my $public_key_file;
    
	my $policy;
	if ($policy_filename eq "") {
	    if ($expires_epoch == 0) {
		print STDERR "Must include policy filename with --policy argument or an expires" . 
		    "time using --expires\n";            
	    }
        
	    $policy = $options->{policy};
	    $policy =~ s/<EXPIRES>/$expires_epoch/g;
	    $policy =~ s/<RESOURCE>/$url/g;
	} else {
	    if (! -e $policy_filename) {
		print STDERR "Policy file $policy_filename does not exist\n";
		exit;
	    }
	    $expires_epoch = 0; # ignore if set
	    $policy = read_file($policy_filename);
	}

	if ($private_key_filename eq "") {
	    print STDERR "You must specific the path to your private key file with --private-key\n";
	    exit;
	}

	if (! -e $private_key_filename) {
	    print STDERR "Private key file $private_key_filename does not exist\n";
	    exit;
	}

	if ($key_pair_id eq "") {
	    print STDERR "You must specify an AWS portal key pair id with --key-pair-id\n";
	    exit;
	}

	my $encoded_policy = url_safe_base64_encode($policy);
	my $signature = rsa_sha1_sign($policy, $private_key_filename);
	my $encoded_signature = url_safe_base64_encode($signature);

	my $generated_url = create_url($url, $encoded_policy, $encoded_signature, $key_pair_id, $expires_epoch);


	if ($stream ne "") {
	    # Escaping this url was *not* good for flow player!!
	    # return escape_url_for_webpage($generated_url);
	    return $generated_url;
	} else {
	    return $generated_url;
	}
    }
}

# Decode a private content URL into its component parts
sub decode_url {
    my $url = shift;

    if ($url =~ /(.*)\?(.*)/) {
        my $base_url = $1;
        my $params = $2;

        my @unparsed_params = split(/&/, $params);
        my %params = ();
        foreach my $param (@unparsed_params) {
            my ($key, $val) = split(/=/, $param);
            $params{$key} = $val;
        }

        my $encoded_signature = "";
        if (exists $params{$SIGNATURE_PARAM}) {
            $encoded_signature = $params{"Signature"};
        } else {
            print STDERR "Missing Signature URL parameter\n";
            return 0;
        }

        my $encoded_policy = "";
        if (exists $params{$POLICY_PARAM}) {
            $encoded_policy = $params{$POLICY_PARAM};
        } else {
            if (!exists $params{$EXPIRES_PARAM}) {
                print STDERR "Either the Policy or Expires URL parameter needs to be specified\n";
                return 0;    
            }
            
            my $expires = $params{$EXPIRES_PARAM};
            
            my $policy = $CANNED_POLICY;
            $policy =~ s/<EXPIRES>/$expires/g;
            
            my $url_without_cf_params = $url;
            $url_without_cf_params =~ s/$SIGNATURE_PARAM=[^&]*&?//g;
            $url_without_cf_params =~ s/$POLICY_PARAM=[^&]*&?//g;
            $url_without_cf_params =~ s/$EXPIRES_PARAM=[^&]*&?//g;
            $url_without_cf_params =~ s/$KEY_PAIR_ID_PARAM=[^&]*&?//g;
            
            if ($url_without_cf_params =~ /(.*)\?$/) {
                $url_without_cf_params = $1;
            }
            
            $policy =~ s/<RESOURCE>/$url_without_cf_params/g;
            
            $encoded_policy = url_safe_base64_encode($policy);
        }

        my $key = "";
        if (exists $params{$KEY_PAIR_ID_PARAM}) {
            $key = $params{$KEY_PAIR_ID_PARAM};
        } else {
            print STDERR "Missing $KEY_PAIR_ID_PARAM parameter\n";
            return 0;
        }

        my $policy = url_safe_base64_decode($encoded_policy);

        my %ret = ();
        $ret{"base_url"} = $base_url;
        $ret{"policy"} = $policy;
        $ret{"key"} = $key;

        return \%ret;
    } else {
        return 0;
    }
}

# Print a decoded URL out
sub print_decoded_url {
    my $decoded = shift;

    print "Base URL: \n" . $decoded->{"base_url"} . "\n";
    print "Policy: \n" . $decoded->{"policy"} . "\n";
    print "Key: \n" . $decoded->{"key"} . "\n";
}

# Encode a string with base 64 encoding and replace some invalid URL characters
sub url_safe_base64_encode {
    my ($value) = @_;

    my $result = encode_base64($value);
    $result =~ tr|+=/|-_~|;

    return $result;
}

# Decode a string with base 64 encoding
sub url_safe_base64_decode {
    my ($value) = @_;

    $value =~ tr|-_~|+=/|;
    my $result = decode_base64($value);

    return $result;
}

# Create a private content URL
sub create_url {
    my ($path, $policy, $signature, $key_pair_id, $expires) = @_;
    
    my $result;
    my $separator = $path =~ /\?/ ? '&' : '?';
    if ($expires) {
        $result = "$path$separator$EXPIRES_PARAM=$expires&$SIGNATURE_PARAM=$signature&$KEY_PAIR_ID_PARAM=$key_pair_id";
    } else {
        $result = "$path$separator$POLICY_PARAM=$policy&$SIGNATURE_PARAM=$signature&$KEY_PAIR_ID_PARAM=$key_pair_id";
    }
    $result =~ s/\n//g;

    return $result;
}

# Sign a document with given private key file.
# The first argument is the document to sign
# The second argument is the name of the private key file
sub rsa_sha1_sign {
    my ($to_sign, $pvkFile) = @_;
    return $rsa_priv->sign( $to_sign );
}

# Helper function to write data to a program
sub write_to_program {
    my ($prog, $data) = @_;

    my $pid = open2(*README, *WRITEME, $prog);
    print WRITEME $data;
    close WRITEME;

    # slurp entire contents of output into scalar
    my $output;
    local $/ = undef;
    $output = <README>;
    close README;

    waitpid($pid, 0);

    return $output;
}

# Read a file into a string and return the string
sub read_file {
    my ($file) = @_;

    open(INFILE, "<$file") or die("Failed to open $file: $!");
    my $str = join('', <INFILE>);
    close INFILE;

    return $str;
}

sub is_url_valid {
    my ($url) = @_;

    # HTTP distributions start with http[s]:// and are the correct thing to sign
    if ($url =~ /^https?:\/\//) {
        return 1;
    } else {
        print STDERR "CloudFront requires absolute URLs for HTTP distributions\n";
        return 0;
    }
}

sub is_stream_valid {
    my ($stream) = @_;

    if ($stream =~ /^rtmp:\/\// or $stream =~ /^\/?cfx\/st/) {
        print STDERR "Streaming distributions require that only the stream name is signed.\n";
        print STDERR "The stream name is everything after, but not including, cfx/st/\n";
        return 0;
    } else {
        return 1;
    }
}

# flash requires that the query parameters in the stream name are url
# encoded when passed in through javascript, etc.  This sub handles the minimal
# required url encoding.
sub escape_url_for_webpage {
    my ($url) = @_;

    $url =~ s/\?/%3F/g;
    $url =~ s/=/%3D/g;
    $url =~ s/&/%26/g;

    return $url;
}

1;
