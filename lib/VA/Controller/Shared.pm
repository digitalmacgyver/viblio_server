package VA::Controller::Shared;
use Moose;
use VA::MediaFile;
use namespace::autoclean;
use URI::Escape;

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
    my $mediafile = $c->model( 'DB::Mediafile' )->find( { uuid => $uuid },
						    { prefetch => 'views' } );
    unless( $mediafile ) {
	$c->log->error( 'Cannot find media file' );
	$c->res->body( $c->req->path . ': ' . $c->loc('Page not found' ));
	$c->res->status( 404 ); # NOT FOUND
	$c->detach;
    }

    my $mhash = VA::MediaFile->new->publish( $c, $mediafile, { expires => (60*60*24*365), aws_use_https => 1 } );

    undef $mediafile;
    $mediafile = $c->model( 'DB::Mediafile' )->find( { uuid => $uuid },
						     { prefetch => 'views' } );

    my $shash = VA::MediaFile->new->publish( $c, $mediafile, { expires => (60*60*24*365), aws_use_https => 0 } );

    my $config = $c->view( 'HTML' )->render( $c, 'shared/fpjs.tt', {no_wrapper => 1, mediafile => $mhash } );
    $config =~ s/\n//g;

    my $insecure_config = $c->view( 'HTML' )->render( $c, 'shared/fpjs-insecure.tt', {no_wrapper => 1, mediafile => $shash } );
    $insecure_config =~ s/\n//g;
    

    $c->stash->{no_wrapper} = 1;
    $c->stash->{server} = $c->req->base;
    $c->stash->{mediafile} = $mhash;
    $c->stash->{insecure}  = $shash;
    $c->stash->{fpconfig}  = uri_escape( $config );
    $c->stash->{fpconfig_insecure}  = uri_escape( $insecure_config );
    $c->stash->{template}  = 'shared/fpheader.tt';
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

sub s3_image_proxy :Chained( '/' ) :PathPart :Args() {
    my( $self, $c ) = @_;
    my $filename = join( '/', @{$c->req->args} );

    # Only expose posters
    unless( $filename =~ /.+_poster\..+$/ ) {
	$c->res->status( 403 );
	$c->res->body( 'Forbidden' );
	$c->detach;
    }
    
    my $bucket = $c->model( 'S3' )->bucket( name => $c->config->{s3}->{bucket} );
    unless( $bucket ) {
	$c->res->status( 404 );
	$c->res->body( 'Not found' );
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
    my $res = $object->client->_send_request( $req );
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
