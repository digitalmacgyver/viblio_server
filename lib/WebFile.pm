package WebFile;
#
# Utilities for upload/download of files.
#
# Depends on a common infrastructure to work ...
#
use FileHandle;
use File::Basename;

sub Upload {
    my( $c, $result,
        $LOC, $obj, $field ) = @_;

    $field = 'upload' unless ( defined( $field ) );

    my $upload = $c->request->upload( $field );
    if ( $upload ) {
        if ( $obj->path ) {
            if ( -f $c->path_to( 'root', '/' . $obj->path ) ) {
                unlink( $c->path_to( 'root', '/' . $obj->path ) );
            }
        }
        $obj->mime_type( $upload->type );
        my $path = $c->path_to( 'root', "$LOC/", $obj->id );
        if ( ! -d $path ) {
            if ( mkdir( $path ) ) {
            }
            else {
                $result->add_error( {
                    name => $field,
                    message => 'mkdir failed' } );
                return 0;
            }
        }
        my $docname = $upload->basename;
        $docname =~ s/\s+/_/g;
        if ( $upload->copy_to( "$path/" . $docname ) ) {
        }
        else {
            $result->add_error( {
                name => $field,
                message => 'upload failed' } );
            return 0;
        }
        $obj->path( "$LOC/" . $obj->id . "/$docname" );
    }
    return 1;
}

sub Download {
    my( $c, $doc ) = @_;

    my $path = $c->path_to( 'root', 
                            $doc->path );

    my $type = $doc->mime_type;
    my $name = basename( $path );

    my $len = -s $path;

    $c->res->body( "Content-type: $type\015\012\015\012" );

    $c->response->headers->header( 'Content-Type' => $type );
    $c->response->headers->header( 'Content-Length' => $len );
    $c->response->headers->header( 'Content-Disposition' => "attachment; filename=\"$name\"" );
    $c->response->headers->header( 'filename' => "\"$name\"" );
    $c->response->headers->header( 'Accept-Ranges' => 'none' );

    $fd = new FileHandle( "$path" );
    if ( ! $fd ) {
        return 0;
    }

    my $blk_size = 1024 * 4;
    my $data;
    my $sz = $fd->read( $data, $blk_size );
    while( $sz > 0 ) {
        $c->response->write( $data );
        $sz = $fd->read( $data, $blk_size );
    }

    $fd->close();

    return 1;
}

1;
