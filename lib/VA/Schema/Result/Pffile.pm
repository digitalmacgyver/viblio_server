use utf8;
package VA::Schema::Result::Pffile;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

=head1 NAME

VA::Schema::Result::Pffile

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

=item * L<DBIx::Class::TimeStamp>

=item * L<DBIx::Class::PassphraseColumn>

=item * L<DBIx::Class::UUIDColumns>

=item * L<DBIx::Class::FilterColumn>

=back

=cut

__PACKAGE__->load_components(
  "InflateColumn::DateTime",
  "TimeStamp",
  "PassphraseColumn",
  "UUIDColumns",
  "FilterColumn",
);

=head1 TABLE: C<pffiles>

=cut

__PACKAGE__->table("pffiles");

=head1 ACCESSORS

=head2 id

  data_type: 'integer'
  is_auto_increment: 1
  is_nullable: 0

=head2 uuid

  data_type: 'text'
  is_nullable: 1

=head2 mimetype

  data_type: 'varchar'
  is_nullable: 0
  size: 64

=head2 filename

  data_type: 'varchar'
  is_nullable: 0
  size: 64

=head2 url

  data_type: 'text'
  is_nullable: 1

=head2 s3key

  data_type: 'text'
  is_nullable: 1

=head2 size

  data_type: 'integer'
  default_value: 0
  is_nullable: 1

=head2 iswritable

  data_type: 'integer'
  default_value: 1
  is_nullable: 1

=head2 user_id

  data_type: 'integer'
  default_value: 0
  is_foreign_key: 1
  is_nullable: 0

=head2 location

  data_type: 'varchar'
  default_value: 'fp'
  is_nullable: 0
  size: 28

=head2 thumbnail_1

  data_type: 'text'
  is_nullable: 1

=head2 thumbnail_2

  data_type: 'text'
  is_nullable: 1

=head2 poster_1

  data_type: 'text'
  is_nullable: 1

=head2 poster_2

  data_type: 'text'
  is_nullable: 1

=cut

__PACKAGE__->add_columns(
  "id",
  { data_type => "integer", is_auto_increment => 1, is_nullable => 0 },
  "uuid",
  { data_type => "text", is_nullable => 1 },
  "mimetype",
  { data_type => "varchar", is_nullable => 0, size => 64 },
  "filename",
  { data_type => "varchar", is_nullable => 0, size => 64 },
  "url",
  { data_type => "text", is_nullable => 1 },
  "s3key",
  { data_type => "text", is_nullable => 1 },
  "size",
  { data_type => "integer", default_value => 0, is_nullable => 1 },
  "iswritable",
  { data_type => "integer", default_value => 1, is_nullable => 1 },
  "user_id",
  {
    data_type      => "integer",
    default_value  => 0,
    is_foreign_key => 1,
    is_nullable    => 0,
  },
  "location",
  { data_type => "varchar", default_value => "fp", is_nullable => 0, size => 28 },
  "thumbnail_1",
  { data_type => "text", is_nullable => 1 },
  "thumbnail_2",
  { data_type => "text", is_nullable => 1 },
  "poster_1",
  { data_type => "text", is_nullable => 1 },
  "poster_2",
  { data_type => "text", is_nullable => 1 },
);

=head1 PRIMARY KEY

=over 4

=item * L</id>

=back

=cut

__PACKAGE__->set_primary_key("id");

=head1 RELATIONS

=head2 pffile_workorders

Type: has_many

Related object: L<VA::Schema::Result::PffileWorkorder>

=cut

__PACKAGE__->has_many(
  "pffile_workorders",
  "VA::Schema::Result::PffileWorkorder",
  { "foreign.pffile_id" => "self.id" },
  { cascade_copy => 0, cascade_delete => 0 },
);

=head2 user

Type: belongs_to

Related object: L<VA::Schema::Result::User>

=cut

__PACKAGE__->belongs_to(
  "user",
  "VA::Schema::Result::User",
  { id => "user_id" },
  { is_deferrable => 1, on_delete => "CASCADE", on_update => "CASCADE" },
);

=head2 workorders

Type: many_to_many

Composing rels: L</pffile_workorders> -> workorder

=cut

__PACKAGE__->many_to_many("workorders", "pffile_workorders", "workorder");


# Created by DBIx::Class::Schema::Loader v0.07035 @ 2013-04-04 21:29:48
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:oufRZxeZfo0lJAHlhq3aNQ

__PACKAGE__->uuid_columns( 'uuid' );

sub TO_JSON {
    my $self = shift;
    my $hash = $self->{_column_data};
    if ( $hash->{iswritable} ) {
	$hash->{isWriteable} = "true";
    }
    else {
	$hash->{isWriteable} = "false";
    }
    delete $hash->{iswritable};
    # Use the filter column component to get a fully qualified
    # secure signed S3 url that expires in an hour.
    $hash->{url} = $self->get_filtered_column( 'url' );
    $hash->{thumbnail_1} = $self->get_filtered_column( 'thumbnail_1' );
    $hash->{poster_1} = $self->get_filtered_column( 'poster_1' );
    $hash->{thumbnail_2} = $self->get_filtered_column( 'thumbnail_2' );
    $hash->{poster_2} = $self->get_filtered_column( 'poster_2' );
    return $hash;
}

# This magic creates a secure, signed, timed S3 url for
# files in this bucket, using the filepicker S3 key field as
# the bucket key.  Haven't figure out how to move the
# configuration into the application yaml file where it
# belongs though.
#
# To get this url, you have to call
#  $c->model( 'DB::Pffile')->find($id)->get_filtered_column( 's3key' );
# The TOJSON above does this so any services get the full url, good
# for an hour.
#
use Muck::FS::S3::QueryStringAuthGenerator;
my $key = 'AKIAJHD46VMHB2FBEMMA';
my $secret = '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';
my $use_https = 0;
my $bucket_name = 'viblio.filepicker.io';
my $endpoint = $bucket_name . ".s3.amazonaws.com";
my $generator = Muck::FS::S3::QueryStringAuthGenerator->new(
    $key, $secret, $use_https, $endpoint );

__PACKAGE__->filter_column( 
    url => {
	filter_from_storage => sub {
	    my $loc = $_[0]->get_column( 'location' );
	    return $_[1] if ( $loc ne 's3' );
	    my $url = $generator->get( $bucket_name, $_[1] );
	    # I think amazon must have changed their endpoint architecture
	    # since the example I used to implement this was written, thus
	    # this little hack.
	    $url =~ s/\/$bucket_name\//\//g;
	    return $url;
	}
    });
__PACKAGE__->filter_column( 
    thumbnail_1 => {
	filter_from_storage => sub {
	    return undef unless( $_[1] );
	    my $url = $generator->get( $bucket_name, $_[1] );
	    $url =~ s/\/$bucket_name\//\//g;
	    return $url;
	}
    });
__PACKAGE__->filter_column( 
    poster_1 => {
	filter_from_storage => sub {
	    return undef unless( $_[1] );
	    my $url = $generator->get( $bucket_name, $_[1] );
	    $url =~ s/\/$bucket_name\//\//g;
	    return $url;
	}
    });
__PACKAGE__->filter_column( 
    thumbnail_2 => {
	filter_from_storage => sub {
	    return undef unless( $_[1] );
	    my $url = $generator->get( $bucket_name, $_[1] );
	    $url =~ s/\/$bucket_name\//\//g;
	    return $url;
	}
    });
__PACKAGE__->filter_column( 
    poster_2 => {
	filter_from_storage => sub {
	    return undef unless( $_[1] );
	    my $url = $generator->get( $bucket_name, $_[1] );
	    $url =~ s/\/$bucket_name\//\//g;
	    return $url;
	}
    });

# You can replace this text with custom code or comments, and it will be preserved on regeneration
__PACKAGE__->meta->make_immutable;
1;
