use lib "lib";
use VA;
use Data::Dumper;

$c = VA->new;
$mf = $c->model( 'RDS::Media' )->find({ uuid => $ARGV[0] });

# Leverage the publish routine to obtain faces for
# this mediafile.
my $mediafile = VA::MediaFile->new->publish( $c, $mf, { assets => [], include_contact_info => 1 } );
my @faces = @{$mediafile->{views}->{face}};

# Generic resultset for finding other mediafiles (other than this one)
my $rs = $c->model( 'RDS::MediaAssetFeature' )->search({
    'media.id' => { '!=', $mf->id } }, {
	prefetch => { 'media_asset' => 'media' }, group_by => ['media.id'] } );

foreach my $face ( @faces ) {
    $c->log->debug( "Face: name: " . $face->{contact}->{contact_name} . ", uuid: " . $face->{contact}->{uuid} );
    if ( ! $face->{contact}->{contact_name} ) {
	# unidentified
	$c->log->debug( "  unidentified" );
	# Other mediafiles with this contact
	my $count = $rs->search({'me.contact_id' => $face->{contact}->{id}})->count;
	$c->log->debug( "  -> in $count other videos" );
	if ( $count == 0 ) {
	    # No others, so delete the contact
	    my $contact = $c->model( 'RDS::Contact' )->find({ uuid => $face->{contact}->{uuid} });
	    if ( $contact ) {
		$c->log->debug( "  -> DELETE " . $face->{contact}->{uuid} );
		# $contact->delete; $contact->update;
	    }
	}
    }
    else {
	# identified
	$c->log->debug( "  identified" );
	# Other mediafiles with this contact
	my $count = $rs->search({'me.contact_id' => $face->{contact}->{id}})->count;
	$c->log->debug( "  -> in $count other videos" );
	if ( $count == 0 ) {
	    # In no other videos.  Unset the picture_uri if it points
	    # to this video
	    my $cnt = $c->model( 'RDS::MediaAsset' )->search({
		media_id => $mf->id,
		uri => $face->{contact}->{picture_uri} })->count;
	    if ( $cnt == 0 ) {
		# There is a picture_uri, but it does not point to any
		# of this mediafile's assets, so leave it alone.  It
		# could be a contact with a pic, but not in any video
		# like a FB contact
		$c->log->debug( "  -> PRESERVE picture_uri" );
	    }
	    else {
		my $contact = $c->model( 'RDS::Contact' )->find({ uuid => $face->{contact}->{uuid} });
		if ( $contact ) {
		    # There is a picture_uri, and it points to an asset about to be
		    # deleted, and there are no other videos to which to point to,
		    # so unset the picture_uri.
		    $c->log->debug( "  -> UNSET picture_uri " . $face->{contact}->{uuid} );
		    # $contact->picture_uri( undef ); $contact->update;
		}
	    }
	}
	else {
	    # This person is in other videos.  If the picture_uri points to
	    # one of the assets in this video, then must point it to one of
	    # the assets in one of the other videos.
	    my $cnt = $c->model( 'RDS::MediaAsset' )->search({
		media_id => $mf->id,
		uri => $face->{contact}->{picture_uri} })->count;
	    if ( $cnt == 0 ) {
		# There is a picture_uri, but it does not point to any
		# of this mediafile's assets, so leave it alone.
		$c->log->debug( "  -> PRESERVE picture_uri" );
	    }
	    else {
		# The picture_uri needs to be changed.
		$c->log->debug( "  -> SWITCH picture_uri" );
		my @others = $rs->search({'me.contact_id' => $face->{contact}->{id}});
		if ( $#others >= 0 ) {
		    my $contact = $c->model( 'RDS::Contact' )->find({ uuid => $face->{contact}->{uuid} });
		    if ( $contact ) {
			$c->log->debug( "  -> commit" );
			#$contact->picture_uri( $others[0]->media_asset->uri );
			#$contact->update;
		    }
		}
	    }
	}
    }
}
