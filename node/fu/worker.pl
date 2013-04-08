#!/usr/bin/perl
#
use strict;
use JSON;
use Data::Dumper;
use FileHandle;
use File::Basename;
use LWP::UserAgent;
use URI;
use POSIX qw(strftime);

# Read config
my $config = do "config.pl";
if ( $ENV{'VA_CONFIG_LOCAL_SUFFIX'} &&
     -f "config_" . $ENV{'VA_CONFIG_LOCAL_SUFFIX'} . ".pl" ) {
    $config = do "config_" . $ENV{'VA_CONFIG_LOCAL_SUFFIX'} . ".pl";
}

my $endpoint = $config->{endpoint};

# Logging
my $logf = new FileHandle ">>/tmp/worker.log";
sub logger {
    my $msg = shift;
    my $tm = strftime "%m/%d/%Y %H:%M:%S", localtime;
    print $logf "$tm $msg\n";
}

sub send_error {
    my $msg = shift;
    send_response( $endpoint, {
	error => 1,
	message => $msg } );
}

# We receive one argument, the name of the file
# containing the JSON encoded workorder.
#
my $wofile = $ARGV[0];
logger( "Started with $wofile" );

if ( ! defined( $wofile ) ) {
    logger( "No input file!" );
    send_error( "Worker: Could not obtain WO file from command line." );
    exit 100;
}

# Open, read and convert to JSON
#
my $wof = new FileHandle "<$wofile";
unless( $wof ) {
    logger( "Could not open $wofile: $!" );
    send_error( "Worker: Could not open $wofile: $!" );
    exit 200;
}
my $json = "";
while( <$wof> ) {
    $json .= $_;
}
close $wof;
my $wo = eval {
    from_json( $json );
};
if ( $@ ) {
    logger( "Failed to interpret input: $@" );
    send_error( "Worker: Could not interpret WO JSON: $@" );
    exit 300;
}

# Work on the media
my @media = @{$wo->{media}};
my @s3files = ();
my @toremove = ();

foreach my $fpfile ( @media ) {
    if ( $fpfile->{views}->{'main'} ) {
	my $view = 'main';
	if ( $fpfile->{views}->{$view}->{done} && 
	     ! ( $fpfile->{views}->{$view}->{errored} || $fpfile->{views}->{$view}->{aborted} ) ) {
	    # This file should be good
	    if ( -f $fpfile->{views}->{$view}->{localpath} ) {
		push( @s3files, $fpfile->{views}->{$view}->{localpath} );
		push( @toremove, $fpfile->{views}->{$view}->{localpath} );
	    }
	}
    }

    if ( $fpfile->{views}->{'thumbnail'} ) {
	my $view = 'thumbnail';
	if ( $fpfile->{views}->{$view}->{done} && 
	     ! ( $fpfile->{views}->{$view}->{errored} || $fpfile->{views}->{$view}->{aborted} ) ) {
	    # This file should be good
	    if ( -f $fpfile->{views}->{$view}->{localpath} ) {
		push( @s3files, $fpfile->{views}->{$view}->{localpath} );
		push( @toremove, $fpfile->{views}->{$view}->{localpath} );
	    }
	}
    }
    else {
	# Create thumbnail, and poster if a video
	if ( $fpfile->{views}->{'main'}->{mimetype} =~ /^image/ ) {
	    my $view = 'thumbnail';
	    $fpfile->{views}->{$view} = {};
	    my( $fname, $dn, $bn ) = filenames( $fpfile->{views}->{'main'}->{localpath}, $fpfile->{filename}, 'thumbnail', 'png' );
	    $fname = thumbnail( $fpfile->{views}->{'main'}->{localpath}, $config->{thumbnail_size} || '64x64', $fname );
	    if ( $fname ) {
		push( @s3files, $fname );
		push( @toremove, $fname );
		$fpfile->{views}->{$view}->{localpath} = $fname;
		$fpfile->{views}->{$view}->{filename} = $bn;
		$fpfile->{views}->{$view}->{mimetype} = 'application/png';
	    }
	}
	elsif ( $fpfile->{views}->{'main'}->{mimetype} =~ /^video/ ) {
	    my $view = 'poster';
	    $fpfile->{views}->{$view} = {};
	    my( $fname, $dn, $bn ) = filenames( $fpfile->{views}->{'main'}->{localpath}, $fpfile->{filename}, 'poster', 'png' );
	    $fname = poster( $fpfile->{views}->{'main'}->{localpath}, $config->{poster_width} || '320', $fname );
	    if ( $fname ) {
		push( @s3files, $fname );
		push( @toremove, $fname );
		$fpfile->{views}->{$view}->{localpath} = $fname;
		$fpfile->{views}->{$view}->{filename} = $bn;
		$fpfile->{views}->{$view}->{mimetype} = 'application/png';

		my $tname = $fname;
		$tname =~ s/poster/thumbnail/g;
		my $tbn = $bn;
		$tbn =~ s/poster/thumbnail/g;
		$tname = thumbnail( $fname, $config->{thumbnail_size} || '64x64', $tname );
		if ( $tname ) {
		    push( @s3files, $tname );
		    push( @toremove, $tname );
		    $fpfile->{views}->{'thumbnail'}->{localpath} = $tname;
		    $fpfile->{views}->{'thumbnail'}->{filename} = $tbn;
		    $fpfile->{views}->{'thumbnail'}->{mimetype} = 'application/png';
		}
	    }
	}
    }
}

# Upload to S3
if ( upload_to_s3() == 0 ) {
    # Send the modified workorder back
    send_response( $endpoint, $wo );
}

# delete temporary files
foreach my $file ( @toremove ) {
    unlink( $file );
}
unlink( $wofile );

exit 0;

sub filenames {
    my ($ifile, $sfile, $add, $ext) = @_;
    my $dirname = dirname( $ifile );
    my $basename = basename( $ifile );

    $basename =~ s/\..+$//g;
    $basename .= "_${add}.${ext}";

    $sfile =~ s/\..+$//g;
    $sfile .= "_${add}.${ext}";

    return( "$dirname/$basename", $dirname, $sfile );
}

sub send_response {
    my ( $endpoint, $data ) = @_;

    my $ua = LWP::UserAgent->new;
    my $res = $ua->post( $endpoint,
			 Content_Type => 'application/json',
			 Content => to_json( $data ) );
    if ( $res->code != 200 ) {
	logger( "send_response: bad code: " . $res->code );
    }
}

sub thumbnail {
    my $ifile = shift;
    my $size  = shift;
    my $ofile = shift;
    my $original = $ofile;

    $ifile =~ s/ /\\ /g;
    $ofile =~ s/ /\\ /g;

    my $cmd = "/usr/bin/convert $ifile -resize $size\\\> -size $size xc:white +swap -gravity center -composite $ofile";
    if ( ! system( "$cmd 2>&1 >/dev/null" ) ) {
	return $original;
    }
    else {
	return undef;
    }
}

sub poster {
    my $ifile = shift;
    my $size  = shift;
    my $ofile = shift;
    my $original = $ofile;

    $ifile =~ s/ /\\ /g;
    $ofile =~ s/ /\\ /g;

    my $cmd = "/usr/bin/ffmpegthumbnailer -i $ifile -o $ofile -s $size -f";
    if ( ! system( "$cmd 2>&1 >/dev/null" ) ) {
	return $original;
    }
    else {
	return undef;
    }
}

sub upload_to_s3 {
    # have to escape the spaces in s3files file names.
    # call the node fu with the file list, get output
    # foreach line of output, need to look up fpfile
    #   by filename, then set s3url and location=s3.
    #   Some filenames will be thumbnail and poster,
    #   and need to find by that as well.
    my $err = 0;

    my @clean = ();
    foreach my $file ( @s3files ) {
	$file =~ s/ /\\ /g;
	push( @clean, $file );
    }

    my $cmd = "node fu --no-uuids " . join( ' ', @clean );
    my $f = new FileHandle "$cmd|";
    unless( $f ) {
	logger( "Failed to invoke file uploader!" );
	send_error( "Worker: Failed to upload assets to S3." );
	return 1;
    }
    
    my @media = @{$wo->{media}};
    while( <$f> ) {
	chomp;
	logger( "uploaded: $_" );
	my $info = eval {
	    from_json( $_ );
	};
	if ( $@ ) {
	    logger( "Failed to interpret FU input: $@" );
	    send_error( "Worker: Could not interpret FU JSON: $@" );
	    $err = 1;
	    last;
	}
	# find the fpfile
	my $found = 0;
	foreach my $fpfile ( @media ) {
	    foreach my $view ( keys %{$fpfile->{views}} ) {
		if ( $info->{filename} eq $fpfile->{views}->{$view}->{localpath} ) {
		    $found = 1;
		    if ( $info->{error} eq 'true' ) {
			$fpfile->{views}->{$view}->{fu_error} = 1;
		    }
		    else {
			$fpfile->{views}->{$view}->{uri} = $info->{s3key};
			$fpfile->{views}->{$view}->{location} = 's3';
			$fpfile->{views}->{$view}->{size} = -s $fpfile->{views}->{$view}->{localpath};
		    }
		}
	    }
	}
	if ( ! $found ) {
	    logger( "Cannot find $info->{filename} in wo" );
	    send_error( "Problems uploading to S3" );
	    $err = 1;
	    last;
	}
    }
    close( $f );
    return $err;
}
 
