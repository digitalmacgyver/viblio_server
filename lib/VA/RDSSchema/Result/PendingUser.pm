use utf8;
package VA::RDSSchema::Result::PendingUser;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

=head1 NAME

VA::RDSSchema::Result::PendingUser

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

=head1 TABLE: C<pending_users>

=cut

__PACKAGE__->table("pending_users");

=head1 ACCESSORS

=head2 email

  data_type: 'varchar'
  is_nullable: 0
  size: 128

=head2 password

  data_type: 'varchar'
  is_nullable: 1
  size: 128

=head2 username

  data_type: 'varchar'
  is_nullable: 1
  size: 128

=head2 code

  data_type: 'text'
  is_nullable: 1

=head2 active

  data_type: 'varchar'
  is_nullable: 1
  size: 32

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
  "email",
  { data_type => "varchar", is_nullable => 0, size => 128 },
  "password",
  { data_type => "varchar", is_nullable => 1, size => 128 },
  "username",
  { data_type => "varchar", is_nullable => 1, size => 128 },
  "code",
  { data_type => "text", is_nullable => 1 },
  "active",
  { data_type => "varchar", is_nullable => 1, size => 32 },
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

=item * L</email>

=back

=cut

__PACKAGE__->set_primary_key("email");


# Created by DBIx::Class::Schema::Loader v0.07040 @ 2015-01-31 04:37:43
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:ExFHqCOzMnMdOtYbnFRJmg

sub TO_JSON {
    my $self = shift;
    my $hash = { %{$self->{_column_data}} };
    delete $hash->{password};
    return $hash;
}

__PACKAGE__->add_columns(
    'password' => {
       data_type => 'text',
       passphrase       => 'rfc2307',
       passphrase_class => 'SaltedDigest',
       passphrase_args  => {
           algorithm   => 'SHA-1',
           salt_random => 20,
       },
       passphrase_check_method => 'check_password',
    },
    'active' => {
       data_type => 'datetime',
       inflate_datetime => 1,
       set_on_create => 1, set_on_update => 1,
    },
    );


# You can replace this text with custom code or comments, and it will be preserved on regeneration
__PACKAGE__->meta->make_immutable;
1;
