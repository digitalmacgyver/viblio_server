package VA::MediaFile::S3;
use Moose;
use URI;
use Try::Tiny;
extends 'VA::MediaFile';

sub create {
    my ( $self, $c, $params ) = @_;

    return undef;
}

# Delete all views stored on S3 for this mediafile
sub delete {
    my( $self, $c, $mediafile ) = @_;

    my $bucket = $c->model( 'S3' )->bucket( name => $c->config->{s3}->{bucket} );
    unless( $bucket ) {
	$c->log->debug( "Cannot get s3 bucket: " . 
			$c->config->{s3}->{bucket} );
	return undef;
    }

    my $ret = $mediafile;
    foreach my $view ( $mediafile->views ) {
	my $s3file = $bucket->object( key => $view->uri );
	unless( $s3file ) {
	    $c->log->debug( "Cannot get s3 object for " . $view->uri );
	    $ret = undef;
	    next;
	}
	try {
	    $s3file->delete;
	} catch {
	    $c->log->debug( "Caught exception for " . $view->uri . ": $_" );
	    $ret = undef;
	};
    }

    return $ret;
}

1;
