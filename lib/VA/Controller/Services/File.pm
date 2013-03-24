package VA::Controller::Services::File;
use Moose;
use namespace::autoclean;
use File::Path qw(make_path remove_tree);
use File::Copy;
use Try::Tiny;
use DBIx::Class::UUIDColumns;
use FileHandle;

BEGIN { extends 'VA::Controller::Services' }

sub upload :Local {
    my( $self, $c ) = @_;
   
    # Where are we going to store it?
    my $rootdir = $c->config->{mediapath};
    # If that path is relative, make it relative to the application
    if ( substr( $rootdir, 0, 1 ) ne '/' ) {
	$rootdir = $c->path_to( $rootdir );
    }
    $rootdir = $rootdir . "/" . $c->user->id;

    # Support multiple uploads in a single request.  This operation is
    # atomic; if any problems occur, none of the uploaded files affect
    # the database or the file store.
    #
    my @mediafiles = ();
    my @errors = ();
    for my $field ( $c->req->upload ) {
	my $upload = $c->req->upload( $field );
	my $filename = $upload->basename;
	my $mimetype = $upload->type;
	my $size = $upload->size;
	
    
	# Create a media object instance to store the metadata, but don't
	# store it in the database yet.  We need the uuid field for the
	# filename, and we need to store the final path in the object.
	my $uuid = DBIx::Class::UUIDColumns->get_uuid;
	$c->log->debug( "UUID: " . $uuid );
	my $media = {
	    uuid => $uuid,
	    user_id => $c->user->id,
	    mimetype => $mimetype,
	    filename => $filename,
	    size => $size };

	my $target = $rootdir . "/" . $media->{uuid};
	$media->{path} = $target;

	push( @mediafiles, $media );

	# Make the directory and copy the file ...
	#
	my $error = {};
	if ( ! -d $rootdir ) {
	    if ( make_path( $rootdir ) == 0 ) {
		$c->log->debug( "Failed to create storage dir: $rootdir" );
		$error->{mkdir} = $c->loc("Failed to create storage dir: [_1]", $rootdir ); 
	    }
	}
	if ( ! File::Copy::move( $upload->tempname, $target ) ) {
	    $c->log->debug( "Failed to copy " . $upload->tempname . " to $target" );
	    $error->{copy} = $c->loc("Failed to copy media to: [_1]", $target);
	}
	push( @errors, $error );
    }

    my $exception;
    try {
	$c->model( 'DB' )->schema->txn_do( 
	    sub {
		for( my $i=0; $i<=$#mediafiles; $i++ ) {
		    my $media = $mediafiles[$i];
		    my $error = $errors[$i];
		    die $error->{mkdir} if ( $error->{mkdir} );
		    die $error->{copy} if ( $error->{copy} );
		    my $obj = $c->model( 'DB::Mediafile' )->create( $media );
		    $mediafiles[$i] = $obj;
		    die $c->loc("Failed to create database object for [_1]", $media->{filename})
			unless( $obj );
		}
	    });
    } catch {
	$exception = $_;
    };

    if ( $exception ) {
	# The database is clean, but we might need to remove files from the
	# file store ...
	#
	foreach my $media ( @mediafiles ) {
	    if ( -f $media->{path} ) {
		unlink( $media->{path} );
	    }
	}
	$c->log->debug( "EXCEPTION: " . $exception );
	$self->status_bad_request
	    ( $c, $c->loc( 'Upload failed.' ), "$exception" );
    }
    else {
	$self->status_ok( $c, { media => \@mediafiles } );
    }
}

=head2 /services/file/download

Stream an inline media file to the client.  The response is HTML
with Content-Type set to the mimetype of the media file and
Content-Length set to the file size.  The response is streamed.

This endpoint can be used as the 'src' attribute in <img> tags for
example.

=head3 Parameters

=over

=item id or uuid

Can specifiy either the media file id or uuid to find.  Only media
files from the logged in user are searched.

=back

=cut

sub download :Local {
    my( $self, $c, $id ) = @_;
    $id = $c->req->param( 'id' ) unless( $id );
    $id = $c->req->param( 'uuid' ) unless( $id );
    my $mediafile = $c->user->obj->mediafiles->find({ id => $id });
    # try uuid if not found
    unless( $mediafile ) {
	$mediafile = $c->user->obj->mediafiles->find({ uuid => $id });
    }

    # Not found should return a real html-based 404
    #
    if ( ! $mediafile ||
	 ! -f $mediafile->path ) {
	my $err = $c->loc( "No media file found at id/uuid [_1]", $id );
	$c->res->status( 404 );
	$c->res->body( "404 Not Found\n\n$err" );
	$c->detach;
    }

    my $type = $mediafile->mimetype;
    my $len  = $mediafile->size;

    $c->res->body( "Content-type: $type\015\012\015\012" );

    $c->res->headers->header( 'Content-Type' => $type );
    $c->res->headers->header( 'Content-Length' => $len );

    my $f = new FileHandle $mediafile->path;
    unless( $f ) {
	my $err = $c->loc( "No media file found at id/uuid [_1]", $id );
	$c->res->status( 404 );
	$c->res->body( "404 Not Found\n\n$err" );
	$c->detach;
    }

    my $blk_size = 1024 * 4;
    my $data;
    my $sz = $f->read( $data, $blk_size );
    while( $sz > 0 ) {
        $c->res->write( $data );
        $sz = $f->read( $data, $blk_size );
    }

    $f->close();
}

__PACKAGE__->meta->make_immutable;

1;


