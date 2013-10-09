package VA::Controller::Shared;
use Moose;
use VA::MediaFile;
use namespace::autoclean;
use URI::Escape;
use MIME::Types;
use Try::Tiny;

BEGIN {extends 'Catalyst::Controller'; }

=head2 /shared/flowplayer/$uuid

This unauthenticated API is used in the Flowplayer "viral video"
plugin's 'pageUrl' field, which is the URL sent to Facebook, et. al.
as the link to be shared.  This API returned a generated page that
contains the header metadata with all of the gobblygook required
to share a video.

=cut

sub flowplayer :Local {
    my( $self, $c, $uuid ) = @_;
    $uuid = $c->req->param( 'uuid' ) unless( $uuid );
    my $mediafile = $c->model( 'RDS::Media' )->find( { uuid => $uuid },
						     { prefetch => 'assets' } );

    if ( $mediafile ) {
	# my $mhash = VA::MediaFile->new->publish( $c, $mediafile, { expires => (60*60*24*365), aws_use_https => 1 } );

	# The fpheader needs only limitted information, so don't leak anything
	# we don't have too.
	my $mhash = {
	    title => $mediafile->title,
	    description => $mediafile->description,
	    uuid => $mediafile->uuid,
	    views => {
		poster => {
		    uri => $mediafile->asset( 'poster' )->uri,
		}
	    }
	};

	$c->stash->{no_wrapper} = 1;
	$c->stash->{server} = $c->req->base;
	$c->stash->{mediafile} = $mhash;
	$c->stash->{template}  = 'shared/fpheader.tt';
    }
    else {
	$c->stash->{no_wrapper} = 1;
	$c->stash->{server} = $c->req->base;
	$c->stash->{mediafile} = {};
	$c->stash->{template}  = 'shared/fpheader.tt';
    }
}

sub simple :Local {
    my( $self, $c ) = @_;
    $c->stash->{no_wrapper} = 1;
    $c->stash->{server} = $c->req->base;
    $c->stash->{template}  = 'shared/simple.tt';
}

=head2 /s3_image_proxy/$s3_uri

Sharing on Facebook requires a og:image meta tag who's content points to a publically
accessible image to represent the share.  The og:image content string cannot (apparently)
deal with query params, so we cannot use protected S3 urls.  So this function exists.  
This function is not authenticated since it must be accessible by Facebook servers.  It
takes a mediafile view S3 uri, so the full path looks like a static image URL.  This
function then does the actual S3 assest download, then proxies it out.  So Facebook sees
what appears to be a static, publically accessible image.

The problem is security.  This is an un-authenticated API, which can access any protected
S3 content and return it.  The best I can do is check the passed in uri for ".*_poster\.+$"
which is the convension for storing video posters in S3.  Posters then are exposed, but
no other assets.

=cut

sub s3_image_proxy :Local {
    my( $self, $c, $path, $file ) = @_;
    my $filename = "$path/$file";

    $c->log->debug( 'Filename: ' . $filename );

    # Only expose images
    my $mimetype = MIME::Types->new()->mimeTypeOf( $filename );
    unless( $mimetype ) {
	$c->res->status( 403 );
	$c->res->body( 'Forbidden' );
	$c->detach;
    }
    
    unless( $mimetype =~ /^image/ ) {
	$c->res->status( 403 );
	$c->res->body( 'Forbidden' );
	$c->detach;
    }

    my $exception;
    my $bucket;
    try {
	$bucket = $c->model( 'S3' )->bucket( name => $c->config->{s3}->{bucket} );
    } catch {
	$exception = $_;
    };
    unless( $bucket ) {
	$c->res->status( 404 );
	$c->res->body( 'Not found: ' . $exception );
	$c->detach;
    }

    my $object = $bucket->object( key => $filename );

    my $req = Net::Amazon::S3::Request::GetObject->new
	( s3 => $object->client->s3, 
	  bucket => $object->bucket->name, 
	  key => $object->key, 
	  method => 'GET' )->http_request;
    unless( $req ) {
	$c->res->status( 404 );
	$c->res->body( 'Not found' );
	$c->detach;
    }
    my $res;
    try {
	$res = $object->client->_send_request( $req );
    } catch {
	$exception = $_;
    };
    if ( $exception ) {
	$c->res->status( 404 );
	$c->res->body( 'Not found' );
	$c->detach;
    }
    unless( $res->is_success ) {
	$c->res->status( $res->code );
	$c->res->body( $res->message );
	$c->detach;
    }
    
    $c->res->status( 200 );
    $c->res->headers->header( 'Content-Type' => $res->header( 'Content-Type' ) );
    $c->res->headers->header( 'Content-Length' => $res->header( 'Content-Length' ) );

    $c->res->write( $res->content );
    $c->res->body('');
}

__PACKAGE__->meta->make_immutable;

1;
