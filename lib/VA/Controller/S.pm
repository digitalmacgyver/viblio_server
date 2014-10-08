package VA::Controller::S;
use Moose;
use VA::MediaFile;
use namespace::autoclean;
use URI::Escape;
use MIME::Types;
use Try::Tiny;
use DateTime;

BEGIN {extends 'Catalyst::Controller'; }

=head2 /s/p/$uuid

This unauthenticated API is used in the Flowplayer "viral video"
plugin's 'pageUrl' field, which is the URL sent to Facebook, et. al.
as the link to be shared.  This API returned a generated page that
contains the header metadata with all of the gobblygook required
to share a video.

=cut

sub p :Local {
    my( $self, $c, $uuid ) = @_;
    $uuid = $c->req->param( 'uuid' ) unless( $uuid );
    my $mediafile = $c->model( 'RDS::Media' )->find( { uuid => $uuid },
						     { prefetch => 'assets' } );

    if ( $mediafile ) {
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
	$c->stash->{server} = $c->server;
	$c->stash->{mediafile} = $mhash;
	$c->stash->{template}  = 'shared/fpheader.tt';
    }
    else {
	$c->stash->{no_wrapper} = 1;
	$c->stash->{server} = $c->server;
	$c->stash->{mediafile} = {};
	$c->stash->{template}  = 'shared/fpheader.tt';
    }
}

=head2 /s/x

Used in shares to social sites that are essencially "likes" that
point back to our site.

=cut

sub x :Local {
    my( $self, $c ) = @_;
    $c->stash->{no_wrapper} = 1;
    $c->stash->{server} = $c->server;
    $c->stash->{template}  = 'shared/simple.tt';
}

=head2 /s/ip/$s3_uri

Sharing on Facebook requires a og:image meta tag who's content points to a publically
accessible image to represent the share.  The og:image content string cannot (apparently)
deal with query params, so we cannot use protected S3 urls.  So this function exists.  
This function is not authenticated since it must be accessible by Facebook servers.  It
takes a mediafile view S3 uri, so the full path looks like a static image URL.  This
function then does the actual S3 assest download, then proxies it out.  So Facebook sees
what appears to be a static, publically accessible image.

The problem is security.  This is an un-authenticated API, which can access any protected
S3 content and return it.  So we check mimetype (based on file name extension) and reject
anything that is not an image.

=cut

sub ip :Local {
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
	$c->log->error( "Could not obtain bucket $c->config->{s3}->{bucket}" );
	$c->res->status( 404 );
	$c->res->body( 'Not found: ' . $exception );
	$c->detach;
    }

    try {
	my $object = $bucket->object( key => $filename,
				      expires => DateTime->now->add( days => 1 ) );
	my $data = $object->get;
	$c->res->status( 200 );
	$c->res->headers->header( 'Content-Type' => $mimetype );
	$c->res->headers->header( 'Content-Length' => length( $data ) );

	$c->res->write( $data );
	$c->res->body('');
    } catch {
	my $e = $_;
	$c->log->error( $e );
	$c->res->status( 404 );
	$c->res->body( 'Not found' );
	$c->detach;
    };
}

=head2 /s/ps/<share-uuid>

This is used for turning a potential share into a hidden share.

=cut

sub ps :Local {
    my( $self, $c, $sid ) = @_;

    unless( $sid ) {
	$c->res->status( 404 );
	$c->res->body( 'Not found' );
	$c->detach;
    }

    my $share = $c->model( 'RDS::MediaShare' )->find({uuid=>$sid, share_type=>'potential'});
    unless( $share ) {
	$share = $c->model( 'RDS::MediaShare' )->find({id=>$sid, share_type=>'potential'});
    }

    unless( $share ) {
	$c->res->status( 404 );
	$c->res->body( 'Not found' );
	$c->detach;
    }

    my $mediafile = $share->media;

    if ( $mediafile ) {
	# Turn this potential share into a real, hidden share
	# 
	# There has been some spooky business using
	# find_or_create_related here resulting in duplicates that
	# shouldn't occur - let's try less magic and more explicit
	# code.
	my @hidden_shares = $mediafile->media_shares->search( { share_type => 'hidden' } );
	my $hidden = undef;
	if ( !scalar( @hidden_shares ) ) {
	    # Oops! No such hidden share exists - create one.
	    $hidden = $mediafile->create_related( 'media_shares', 
						  { share_type => 'hidden', 
						    is_group_share => 0, 
						    'view_count' => 0 } );
	} else {
	    $hidden = $hidden_shares[0];
	}


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
	$c->stash->{server} = $c->server;
	$c->stash->{mediafile} = $mhash;
	$c->stash->{template}  = 'shared/fpheader.tt';
    }
    else {
	$c->stash->{no_wrapper} = 1;
	$c->stash->{server} = $c->server;
	$c->stash->{mediafile} = {};
	$c->stash->{template}  = 'shared/fpheader.tt';
    }
}


=head2 /s/e/<share-uuid>

This redirects a potential share which is accessed through an embed
code to the underlying resource.

=cut

sub e :Local {
    my( $self, $c, $sid ) = @_;

    unless( $sid ) {
	$c->res->status( 404 );
	$c->res->body( 'Not found' );
	$c->detach;
    }

    my $share = $c->model( 'RDS::MediaShare' )->find( { uuid=>$sid, share_type=> 'public' } );

    unless( $share ) {
	$c->res->status( 404 );
	$c->res->body( 'Not found' );
	$c->detach;
    }

    my $mediafile = $share->media;

    $mediafile->view_count( $mediafile->view_count + 1 );
    $mediafile->update;
	    
    my $mf = VA::MediaFile->new->publish( $c, $mediafile, { views => [ 'main' ] } );

    my $url = $mf->{views}->{main}->{url};
    my $cf_url = $c->cf_sign( $mf->{views}->{main}->{uri}, { stream => 0, expires => 24*60*60 } );

    $c->response->redirect( $cf_url, 307 );
    $c->detach();
}

__PACKAGE__->meta->make_immutable;

1;
