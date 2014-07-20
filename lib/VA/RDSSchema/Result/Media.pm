use utf8;
package VA::RDSSchema::Result::Media;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

=head1 NAME

VA::RDSSchema::Result::Media

=cut

use strict;
use warnings;

use Moose;
use MooseX::NonMoose;
use MooseX::MarkAsMethods autoclean => 1;
extends 'DBIx::Class::Core';

=head1 COMPONENTS LOADED

=over 4

=item * L<DBIx::Class::InflateColumn::DateTime>

=item * L<DBIx::Class::ColumnDefault>

=item * L<DBIx::Class::TimeStamp>

=item * L<DBIx::Class::PassphraseColumn>

=item * L<DBIx::Class::UUIDColumns>

=item * L<DBIx::Class::FilterColumn>

=back

=cut

__PACKAGE__->load_components(
  "InflateColumn::DateTime",
  "ColumnDefault",
  "TimeStamp",
  "PassphraseColumn",
  "UUIDColumns",
  "FilterColumn",
);

=head1 TABLE: C<media>

=cut

__PACKAGE__->table("media");

=head1 ACCESSORS

=head2 id

  data_type: 'integer'
  is_auto_increment: 1
  is_nullable: 0

=head2 user_id

  data_type: 'integer'
  is_foreign_key: 1
  is_nullable: 0

=head2 uuid

  data_type: 'varchar'
  is_nullable: 0
  size: 36

=head2 unique_hash

  data_type: 'varchar'
  is_nullable: 1
  size: 32

=head2 media_type

  data_type: 'varchar'
  is_foreign_key: 1
  is_nullable: 0
  size: 16

=head2 is_album

  data_type: 'tinyint'
  default_value: 0
  is_nullable: 1

=head2 title

  data_type: 'varchar'
  is_nullable: 1
  size: 200

=head2 filename

  data_type: 'varchar'
  is_nullable: 1
  size: 1024

=head2 description

  data_type: 'varchar'
  is_nullable: 1
  size: 1024

=head2 recording_date

  data_type: 'datetime'
  datetime_undef_if_invalid: 1
  is_nullable: 1

=head2 view_count

  data_type: 'integer'
  is_nullable: 1

=head2 lat

  data_type: 'decimal'
  is_nullable: 1
  size: [11,8]

=head2 lng

  data_type: 'decimal'
  is_nullable: 1
  size: [11,8]

=head2 geo_address

  data_type: 'varchar'
  is_nullable: 1
  size: 256

=head2 geo_city

  data_type: 'varchar'
  is_nullable: 1
  size: 128

=head2 status

  data_type: 'varchar'
  is_nullable: 1
  size: 32

=head2 is_viblio_created

  data_type: 'tinyint'
  default_value: 0
  is_nullable: 0

=head2 created_date

  data_type: 'datetime'
  datetime_undef_if_invalid: 1
  is_nullable: 1

=head2 updated_date

  data_type: 'datetime'
  datetime_undef_if_invalid: 1
  is_nullable: 1

=cut

__PACKAGE__->add_columns(
  "id",
  { data_type => "integer", is_auto_increment => 1, is_nullable => 0 },
  "user_id",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 0 },
  "uuid",
  { data_type => "varchar", is_nullable => 0, size => 36 },
  "unique_hash",
  { data_type => "varchar", is_nullable => 1, size => 32 },
  "media_type",
  { data_type => "varchar", is_foreign_key => 1, is_nullable => 0, size => 16 },
  "is_album",
  { data_type => "tinyint", default_value => 0, is_nullable => 1 },
  "title",
  { data_type => "varchar", is_nullable => 1, size => 200 },
  "filename",
  { data_type => "varchar", is_nullable => 1, size => 1024 },
  "description",
  { data_type => "varchar", is_nullable => 1, size => 1024 },
  "recording_date",
  {
    data_type => "datetime",
    datetime_undef_if_invalid => 1,
    is_nullable => 1,
  },
  "view_count",
  { data_type => "integer", is_nullable => 1 },
  "lat",
  { data_type => "decimal", is_nullable => 1, size => [11, 8] },
  "lng",
  { data_type => "decimal", is_nullable => 1, size => [11, 8] },
  "geo_address",
  { data_type => "varchar", is_nullable => 1, size => 256 },
  "geo_city",
  { data_type => "varchar", is_nullable => 1, size => 128 },
  "status",
  { data_type => "varchar", is_nullable => 1, size => 32 },
  "is_viblio_created",
  { data_type => "tinyint", default_value => 0, is_nullable => 0 },
  "created_date",
  {
    data_type => "datetime",
    datetime_undef_if_invalid => 1,
    is_nullable => 1,
  },
  "updated_date",
  {
    data_type => "datetime",
    datetime_undef_if_invalid => 1,
    is_nullable => 1,
  },
);

=head1 PRIMARY KEY

=over 4

=item * L</id>

=item * L</user_id>

=back

=cut

__PACKAGE__->set_primary_key("id", "user_id");

=head1 UNIQUE CONSTRAINTS

=head2 C<unique_hash_UNIQUE>

=over 4

=item * L</unique_hash>

=item * L</user_id>

=back

=cut

__PACKAGE__->add_unique_constraint("unique_hash_UNIQUE", ["unique_hash", "user_id"]);

=head2 C<uuid_UNIQUE>

=over 4

=item * L</uuid>

=back

=cut

__PACKAGE__->add_unique_constraint("uuid_UNIQUE", ["uuid"]);

=head1 RELATIONS

=head2 communities_medias

Type: has_many

Related object: L<VA::RDSSchema::Result::Community>

=cut

__PACKAGE__->has_many(
  "communities_medias",
  "VA::RDSSchema::Result::Community",
  { "foreign.media_id" => "self.id" },
  { cascade_copy => 0, cascade_delete => 0 },
);

=head2 communities_pending

Type: has_many

Related object: L<VA::RDSSchema::Result::Community>

=cut

__PACKAGE__->has_many(
  "communities_pending",
  "VA::RDSSchema::Result::Community",
  { "foreign.pending_id" => "self.id" },
  { cascade_copy => 0, cascade_delete => 0 },
);

=head2 media_albums_albums

Type: has_many

Related object: L<VA::RDSSchema::Result::MediaAlbum>

=cut

__PACKAGE__->has_many(
  "media_albums_albums",
  "VA::RDSSchema::Result::MediaAlbum",
  { "foreign.album_id" => "self.id" },
  { cascade_copy => 0, cascade_delete => 0 },
);

=head2 media_albums_medias

Type: has_many

Related object: L<VA::RDSSchema::Result::MediaAlbum>

=cut

__PACKAGE__->has_many(
  "media_albums_medias",
  "VA::RDSSchema::Result::MediaAlbum",
  { "foreign.media_id" => "self.id" },
  { cascade_copy => 0, cascade_delete => 0 },
);

=head2 media_assets

Type: has_many

Related object: L<VA::RDSSchema::Result::MediaAsset>

=cut

__PACKAGE__->has_many(
  "media_assets",
  "VA::RDSSchema::Result::MediaAsset",
  {
    "foreign.media_id" => "self.id",
    "foreign.user_id"  => "self.user_id",
  },
  { cascade_copy => 0, cascade_delete => 0 },
);

=head2 media_comments

Type: has_many

Related object: L<VA::RDSSchema::Result::MediaComment>

=cut

__PACKAGE__->has_many(
  "media_comments",
  "VA::RDSSchema::Result::MediaComment",
  { "foreign.media_id" => "self.id" },
  { cascade_copy => 0, cascade_delete => 0 },
);

=head2 media_shares

Type: has_many

Related object: L<VA::RDSSchema::Result::MediaShare>

=cut

__PACKAGE__->has_many(
  "media_shares",
  "VA::RDSSchema::Result::MediaShare",
  { "foreign.media_id" => "self.id" },
  { cascade_copy => 0, cascade_delete => 0 },
);

=head2 media_type

Type: belongs_to

Related object: L<VA::RDSSchema::Result::MediaType>

=cut

__PACKAGE__->belongs_to(
  "media_type",
  "VA::RDSSchema::Result::MediaType",
  { type => "media_type" },
  { is_deferrable => 1, on_delete => "CASCADE", on_update => "CASCADE" },
);

=head2 media_workflow_stages

Type: has_many

Related object: L<VA::RDSSchema::Result::MediaWorkflowStage>

=cut

__PACKAGE__->has_many(
  "media_workflow_stages",
  "VA::RDSSchema::Result::MediaWorkflowStage",
  {
    "foreign.media_id" => "self.id",
    "foreign.user_id"  => "self.user_id",
  },
  { cascade_copy => 0, cascade_delete => 0 },
);

=head2 user

Type: belongs_to

Related object: L<VA::RDSSchema::Result::User>

=cut

__PACKAGE__->belongs_to(
  "user",
  "VA::RDSSchema::Result::User",
  { id => "user_id" },
  { is_deferrable => 1, on_delete => "CASCADE", on_update => "CASCADE" },
);

=head2 viblio_added_contents

Type: has_many

Related object: L<VA::RDSSchema::Result::ViblioAddedContent>

=cut

__PACKAGE__->has_many(
  "viblio_added_contents",
  "VA::RDSSchema::Result::ViblioAddedContent",
  {
    "foreign.media_id"      => "self.id",
    "foreign.media_user_id" => "self.user_id",
  },
  { cascade_copy => 0, cascade_delete => 0 },
);


# Created by DBIx::Class::Schema::Loader v0.07036 @ 2014-05-06 16:57:33
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:FFlLX+pZg6jOMfQwWZ7yHw

__PACKAGE__->uuid_columns( 'uuid' );

sub TO_JSON {
    my $self = shift;
    my $params = shift;
    my $hash = { %{$self->{_column_data}} };
    delete $hash->{id};
    delete $hash->{user_id};
    # If our caller already knows who owns this media, they can tell
    # us to avoid doing a DB query.
    if ( defined( $params ) && $params->{owner_uuid} ) {
	$hash->{owner_uuid} = $params->{owner_uuid};
    } else {
	# This results in a database query.
	$hash->{owner_uuid} = $self->user->uuid;
    }
    return $hash;
}

# I like this relationship name better
#
__PACKAGE__->has_many(
  "assets",
  "VA::RDSSchema::Result::MediaAsset",
  { "foreign.media_id" => "self.id" },
  { cascade_copy => 0, cascade_delete => 0 },
);

__PACKAGE__->has_many(
  "comments",
  "VA::RDSSchema::Result::MediaComment",
  { "foreign.media_id" => "self.id" },
  { cascade_copy => 0, cascade_delete => 0 },
);

# Accessor to return the first asset of the matching type.
#
sub asset {
    my( $self, $type ) = @_;
    my $assets = $self->assets;
    if ( $assets ) {
        my $types = $assets->search({asset_type=>$type});
        if ( $types ) {
            return $types->first;
        }
    }
    return undef;
}

# Return all of the assets representing faces
#
sub faces {
    my( $self ) = @_;
    my @faces = ();
    foreach( $self->assets ) {
	push( @faces, $_ ) if ( $_->{_column_data}->{asset_type} eq 'face' ); 
    }
    return @faces;
}

# Given a face asset, return the contact info if any
#
sub face_data {
    my( $self, $face ) = @_;
    my $feat = $face->features->first({ feature_type => 'face' });
    return undef unless( $feat );
    return undef unless( $feat->contact_id );
    return $feat->contact;
}

__PACKAGE__->has_many(
  "media_albums_albums",
  "VA::RDSSchema::Result::MediaAlbum",
  { "foreign.media_id" => "self.id" },
  { cascade_copy => 0, cascade_delete => 0 },
);
__PACKAGE__->has_many(
  "media_albums_medias",
  "VA::RDSSchema::Result::MediaAlbum",
  { "foreign.album_id" => "self.id" },
  { cascade_copy => 0, cascade_delete => 0,
    where => { "media.is_album" => 0,
	       -or => [ "media.status" => "visible",
			"media.status" => "complete" ] }
  },
);
__PACKAGE__->has_many(
  "media_albums_videos",
  "VA::RDSSchema::Result::MediaAlbum",
  { "foreign.album_id" => "self.id" },
  { cascade_copy => 0, cascade_delete => 0,
    where => { "videos.is_album" => 0,
	       -or => [ "videos.status" => "visible",
			"videos.status" => "complete" ] }
  },
);
__PACKAGE__->many_to_many( 'albums', 'media_albums_albums', 'album' );
__PACKAGE__->many_to_many( 'media',  'media_albums_medias', 'media' );
__PACKAGE__->many_to_many( 'videos',  'media_albums_videos', 'videos' );

__PACKAGE__->has_one(
    "community",
    "VA::RDSSchema::Result::Community",
    { "foreign.media_id" => "self.id" },
);

# Called with an album uuid, return 1/0 if video is a member of
# Called with no arg, return list of albums video is a member of
sub is_member_of {
    my( $self, $gid ) = @_;
    if ( $gid ) {
	my $rs = $self->result_source->schema->resultset( 'MediaAlbum' )->search
	    ({'videos.id'=>$self->id,
	      'album.uuid' => $gid},
	     {prefetch=>['videos','album']});
	if ( $rs ) { return $rs->count; }
	else { return 0; }
    }
    else {
	my @cgroups = $self->result_source->schema->resultset( 'MediaAlbum' )->search
	    ({'videos.id'=>$self->id},
	     {prefetch=>['videos','album']});
	return map { $_->album } @cgroups;
    }
}

# Called with a community uuid, return 1/0 if video is a member of
# Called with no arg, return list of communities video is a member of
sub is_community_member_of {
    my( $self, $gid ) = @_;
    if ( $gid ) {
	my $rs = $self->result_source->schema->resultset( 'MediaAlbum' )->search
	    ({'videos.id'=>$self->id,
	      'community.uuid' => $gid},
	     {prefetch=>['videos',{'album'=>'community'}]});
	if ( $rs ) { return $rs->count; }
	else { return 0; }
    }
    else {
	my @cgroups = $self->result_source->schema->resultset( 'MediaAlbum' )->search
	    ({'videos.id'=>$self->id},
	     {prefetch=>['videos',{'album'=>'community'}]});
	return map { $_->album->community } @cgroups;
    }
}

# Add a simple tag to a video or album
sub add_tag {
    my( $self, $tag ) = @_;
    my $asset = $self->assets->find({ asset_type => 'main' });
    my $feature = $asset->find_or_create_related( 'media_asset_features', {
	media_id => $asset->media_id,
	user_id => $asset->user_id,
	feature_type => 'activity',
	coordinates => $tag });
    return $feature;
}

# Remove a simple tag from a video or album
sub rm_tag {
    my( $self, $tag ) = @_;
    my $asset = $self->assets->find({ asset_type => 'main' });
    my $feature = $asset->find_related( 'media_asset_features', {
	media_id => $asset->media_id,
	user_id => $asset->user_id,
	feature_type => 'activity',
	coordinates => $tag });
    if ( $feature ) {
	$feature->delete;
    }
    return $feature;
}

# Return the list of MediaAssetFeatures that represent
# activities (feature_type=activity, coordinates=(baseball).
# This method returns only the unique ones.
sub unique_activities {
    my( $self ) = @_;
    my $rs = $self->result_source->schema->resultset( 'MediaAssetFeature' )->search(
	{ 'media.id' => $self->id,
	  'me.feature_type' => 'activity' },
	{ prefetch => { 'media_asset' => 'media' },
	  group_by => ['coordinates'] } );
    return $rs;
}

# Same as above, but returns the complete list, say if baseball
# occurs more than once in the video.
sub activities {
    my( $self ) = @_;
    my $rs = $self->result_source->schema->resultset( 'MediaAssetFeature' )->search(
	{ 'media.id' => $self->id,
	  'me.feature_type' => 'activity' },
	{ prefetch => { 'media_asset' => 'media' } } );
    return $rs;
}

# Same as the two "activities' above, but throws in faces as well,
# in case you want to treat a face as being an activity, such as
# "this video contains soccer, and this video contains faces"
sub unique_people {
    my( $self ) = @_;
    my $rs = $self->result_source->schema->resultset( 'MediaAssetFeature' )->search(
	{ 'media.id' => $self->id,
	  'me.contact_id' => { '!=', undef },
	  'me.feature_type' => 'face' },
	{ prefetch => { 'media_asset' => 'media' },
	  group_by => ['me.contact_id'] } );
    return $rs;
}

sub people {
    my( $self ) = @_;
    my $rs = $self->result_source->schema->resultset( 'MediaAssetFeature' )->search(
	{ 'media.id' => $self->id,
	  'me.contact_id' => { '!=', undef },
	  'me.feature_type' => 'face' },
	{ prefetch => { 'media_asset' => 'media' } } );
    return $rs;
}

# Lumps activities and people into one fetch.  Must be unniqueified by
# the caller. 
sub people_or_activities {
    my( $self ) = @_;
    my $rs = $self->result_source->schema->resultset( 'MediaAssetFeature' )->search(
	{ 'media.id' => $self->id,
	  -or => [ 'me.feature_type' => 'activity',
		   -and => [ 'me.feature_type' => 'face',
			     'me.contact_id' => { '!=', undef } ] ] },
	{ prefetch => { 'media_asset' => 'media' } } );
    return $rs;
}

# This method returns a simple array of unique tags that can be used
# when publishing a media file.
sub tags {
    my( $self ) = @_;
    my @feats = $self->people_or_activities->all ;
    my $hash  = {};
    foreach my $feat ( @feats ) {
        my $atype = $feat->{_column_data}->{feature_type};
        if ( $atype eq 'face' ) { $hash->{people} = 1; }
        else { $hash->{$feat->coordinates} = 1; }
    }
    my @tags = keys %$hash;
    return @tags;
}

__PACKAGE__->meta->make_immutable;
1;
