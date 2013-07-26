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
use XML::Simple;

# Read config
my $config = do "config.pl";
if ( $ENV{'VA_CONFIG_LOCAL_SUFFIX'} &&
     -f "config_" . $ENV{'VA_CONFIG_LOCAL_SUFFIX'} . ".pl" ) {
    my $config_env = do "config_" . $ENV{'VA_CONFIG_LOCAL_SUFFIX'} . ".pl";
    foreach my $key ( keys( %$config_env ) ) {
	$config->{$key} = $config_env->{$key};
    }
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

# To bootstrap Siabal
logger( wo2xml( $wo ) );

# Work on the media
my @media = @{$wo->{media}};
my @s3files = ();
my @toremove = ();

foreach my $fpfile ( @media ) {
    if ( $fpfile->{views}->{'main'} ) {
	my $view = $fpfile->{views}->{'main'};
	my $uuid = $fpfile->{uuid};
	if ( $view->{done} && ! ( $view->{errored} || $view->{aborted} ) ) {
	    # This file should be good
	    if ( -f $view->{localpath} ) {
		my $infile = $view->{localpath};
		my( $in_bn, $in_dn, $in_ext ) = fileparse( $infile, qr/\.[^.]*/ );

		push( @toremove, $view->{localpath} );

		# If its a video and its not already video/mp4, then transcode
		# it into mp4 and replace the original.
		if ( $view->{mimetype} ne 'video/mp4' ) {
		    my $newfile = "${in_dn}${in_bn}.mp4";
		    my $res = xcode( $infile, $newfile );
		    if ( $res eq $newfile ) {
			# Successful
			logger( "successful transcode!" );
			$infile = $newfile;
			( $in_bn, $in_dn, $in_ext ) = fileparse( $infile, qr/\.[^.]*/ );
			my( $fn_bn, $fn_dn, $fn_ext ) = fileparse( $view->{filename}, qr/\.[^.]*/ );
			$view->{localpath} = $infile;
			$view->{filename} = "${fn_bn}.mp4";
			$fpfile->{filename} = "${fn_bn}.mp4";
			$view->{mimetype} = 'video/mp4';
			$view->{size} = -s $infile;
			push( @toremove, $view->{localpath} );
		    }
		}
		else {
		    # Its already mp4, but we still need to fix the metadata position
		    fix_video( $infile );
		}
		push( @s3files, $uuid . '^' . $view->{localpath} );
		$view->{uri} = $uuid . '/' . basename( $view->{localpath} );
		$view->{location} = 's3';

		# If this is a video, create a poster view and a thumbnail view.  I currently
		# support only one poster size, but multiple thumbnail sizes.  So we create a poster
		# from the video, then we create multiple thumbnails from that poster.

		# The poster and thumbnail filenames and s3 keys are derived from information
		# from the main view.
		
		if ( $view->{mimetype} =~ /^video/ ) {
		    my $s3key = "${in_bn}_poster.png";
		    my $ofile = "${in_dn}${s3key}";
		    $ofile = poster( $infile, $config->{poster_width} || '320', $ofile );
		    if ( $ofile ) {
			push( @s3files, $uuid . '^' . $ofile );
			push( @toremove, $ofile );
			$fpfile->{views}->{poster}->{localpath} = $ofile;
			$fpfile->{views}->{poster}->{filename} = $fpfile->{views}->{main}->{filename};
			$fpfile->{views}->{poster}->{mimetype} = 'image/png';
			$fpfile->{views}->{poster}->{uri} = "$uuid/$s3key";
			$fpfile->{views}->{poster}->{location} = 's3';
			$fpfile->{views}->{poster}->{size} = -s $ofile;
		    }

		    # Create a metadata view
		    $s3key = "${in_bn}_metadata.json";
		    my $mfile = "${in_dn}${s3key}";
		    $mfile = metadata( $infile, $mfile );
		    if ( $mfile ) {
			push( @s3files, $uuid . '^' . $mfile );
			push( @toremove, $mfile );
			$fpfile->{views}->{metadata}->{localpath} = $mfile;
			$fpfile->{views}->{metadata}->{filename} = $fpfile->{views}->{main}->{filename};
			$fpfile->{views}->{metadata}->{mimetype} = 'application/json';
			$fpfile->{views}->{metadata}->{uri} = "$uuid/$s3key";
			$fpfile->{views}->{metadata}->{location} = 's3';
			$fpfile->{views}->{metadata}->{size} = -s $mfile;
		    }

		    $infile = $ofile;  # input to thumbnails for video is poster
		}
		
		if ( $view->{mimetype} =~ /^image/ || $view->{mimetype} =~ /^video/ ) {
		    my $s3key = "${in_bn}_thumbnail";
		    my $ofile = "${in_dn}${s3key}";
		    $fpfile->{views}->{thumbnail}->{localpath} = $ofile;
		    $fpfile->{views}->{thumbnail}->{filename} = $fpfile->{views}->{main}->{filename};
		    $fpfile->{views}->{thumbnail}->{mimetype} = 'image/png';
		    $fpfile->{views}->{thumbnail}->{uri} = "$uuid/$s3key";
		    $fpfile->{views}->{thumbnail}->{location} = 's3';
		    foreach my $size ( @{$config->{thumbnail_sizes}} ) {
			my $tout = $ofile . "_" . $size . ".png";
			$tout = thumbnail( $infile, $size, $tout );
			if ( $tout ) {
			    push( @s3files, $uuid . '^' . $tout );
			    push( @toremove, $tout );
			    $fpfile->{views}->{thumbnail}->{size} = -s $tout;
			}
		    }
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

sub send_response {
    my ( $endpoint, $data ) = @_;

    my $ua = LWP::UserAgent->new;
    my $res = $ua->post( $endpoint,
			 Content_Type => 'application/json',
			 Content => to_json( $data ) );
    if ( $res->code != 200 ) {
	logger( "send_response: bad code: " . $res->code );
	logger( "endpoint was: " . $endpoint );
    }
    else {
	logger( "sent response to $endpoint" );
    }
}

sub thumbnail {
    my $ifile = shift;
    my $size  = shift;
    my $ofile = shift;
    my $original = $ofile;

    $ifile =~ s/ /\\ /g;
    $ofile =~ s/ /\\ /g;

    $ifile =~ s/\(/\\(/g;
    $ifile =~ s/\)/\\)/g;

    $ofile =~ s/\(/\\(/g;
    $ofile =~ s/\)/\\)/g;

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

    $ifile =~ s/\(/\\(/g;
    $ifile =~ s/\)/\\)/g;

    $ofile =~ s/\(/\\(/g;
    $ofile =~ s/\)/\\)/g;

    my $cmd = "/usr/bin/ffmpegthumbnailer -i $ifile -o $ofile -s $size";
    if ( ! system( "$cmd 2>&1 >/dev/null" ) ) {
	# Now fit this image into a 4:3 box, assuming $size is a width
	my $w = $size;
	my $h = int( ($w/4)*3 );
	$cmd = "/usr/bin/convert $ofile -resize ${w}x${h}\\\> -size ${w}x${h} xc:black  +swap -gravity center -composite $ofile";
	if ( ! system( "$cmd 2>&1 >/dev/null" ) ) {
	    return $original;
	}
	else {
	    return undef;
	}
    }
    else {
	return undef;
    }
}

sub metadata {
    my $ifile = shift;
    my $ofile = shift;
    my $original = $ofile;

    $ifile =~ s/ /\\ /g;
    $ofile =~ s/ /\\ /g;

    $ifile =~ s/\(/\\(/g;
    $ifile =~ s/\)/\\)/g;

    $ofile =~ s/\(/\\(/g;
    $ofile =~ s/\)/\\)/g;

    logger( 'Obtaining metadata ...' );
    my $cmd = "/usr/local/bin/ffprobe -v quiet -print_format json=c=1 -show_format -show_streams $ifile > $ofile";
    if ( ! system( "$cmd" ) ) {
	return $original;
    }
    else {
	logger( "Command failed: " . $cmd . ": " . $? );
	return undef;
    }
}

# Use python-based qtfaststart ( https://github.com/danielgtaylor/qtfaststart )
# to move the metadata in quicktime, mp4 and m4v files to the
# start of the video to make streaming better.
#
sub fix_video {
    my ( $infile, $mimetype ) = @_;

    if ( $mimetype eq 'video/quicktime' ||
	 $mimetype eq 'video/mp4' ||
	 $mimetype eq 'video/x-m4v' ) {
	if ( -x "/usr/local/bin/qtfaststart" ) {
	    logger( "qtfaststarting $infile ..." );
	    my $cmd = "/usr/local/bin/qtfaststart $infile";
	    system( "$cmd 2>&1 >/dev/null" );
	}
    }
}

# Transcode a video into .mp4
#
sub xcode {
    my( $infile, $outfile ) = @_;
    logger( "transcoding $infile to $outfile ..." );
    my $cmd = "ffmpeg -v 0 -y -i $infile $outfile";
    if ( system( "$cmd </dev/null 2>&1 >/dev/null" ) ) {
	logger( "Failed to transcode $infile to $outfile" );
	return $infile;
    }
    else {
	fix_video( $outfile, 'video/mp4' );
	return $outfile
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
	$file =~ s/\(/\\(/g;
	$file =~ s/\)/\\)/g;
	push( @clean, $file );
    }

    my $cmd = "node fu --no-uuids " . join( ' ', @clean );
    logger( "invoking: " . $cmd );
    my $f = new FileHandle "$cmd|";
    unless( $f ) {
	logger( "Failed to invoke file uploader!" );
	send_error( "Worker: Failed to upload assets to S3." );
	return 1;
    }
    
    my @media = @{$wo->{media}};
    my $loop_count = 0;
    while( <$f> ) {
	chomp;
	logger( "uploaded: $_" );
	$loop_count += 1;
	my $info = eval {
	    from_json( $_ );
	};
	if ( $@ ) {
	    logger( "Failed to interpret FU input: $@" );
	    send_error( "Worker: Could not interpret FU JSON: $@" );
	    $err = 1;
	    last;
	}
    }

    close( $f );

    if ( $err == 0 && $loop_count != ($#clean + 1) ) {
	send_error( "Problems uploading to S3" );
	$err = 1;
    }
    return $err;
}
 
sub simplify {
    my $wo = shift;
    my $r = {};

    $r->{wo}->{name} = $wo->{wo}->{name};
    $r->{wo}->{uuid} = $wo->{wo}->{uuid};
    $r->{wo}->{'site-token'} = $wo->{wo}->{'site-token'};

    $r->{media} = ();
    foreach my $m ( @{$wo->{media}} ) {
	my $rm = { filename => $m->{filename},
		   uuid => $m->{uuid} };
	foreach my $v ( keys( %{$m->{views}} ) ) {
	    $rm->{views}->{$v}->{uuid} = $m->{views}->{$v}->{uuid};
	    $rm->{views}->{$v}->{size} = $m->{views}->{$v}->{size};
	    $rm->{views}->{$v}->{filename} = $m->{views}->{$v}->{filename};
	    $rm->{views}->{$v}->{type} = $m->{views}->{$v}->{type};
	    $rm->{views}->{$v}->{localpath} = $m->{views}->{$v}->{localpath};
	    $rm->{views}->{$v}->{mimetype} = $m->{views}->{$v}->{mimetype};
	}
	push( @{$r->{media}}, $rm );
    }
    return $r;
}

sub wo2xml {
    my $wo = shift;
    return XMLout( simplify( $wo ),
		   AttrIndent => 1,
		   RootName => 'root',
		   XMLDecl => 1,
		   KeyAttr => [] );
}
