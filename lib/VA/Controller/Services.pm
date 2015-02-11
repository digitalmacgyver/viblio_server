package VA::Controller::Services;
use Moose;
use namespace::autoclean;
use JSON::XS ();
use Email::AddressParser;
use Email::Address;
use Net::Nslookup;
use Try::Tiny;
use Scalar::Util qw/looks_like_number/;

use Net::APNS;

# My own 'REST' controller.  Catalyst::Controller::REST was just too restrictive
# on the inputs and input methods.  I want my user's to be able to use get, put 
# and post freely, and to be able to pass params as uri args, form inputs or json
# encoded bodies as they see fit.
#
# I also want to be able to freely forward() to these services from within web
# controllers using HTML views without having to goof around with the $c->req
# to make Catalyst::Controller::REST happy,

my $encoder = JSON::XS
    ->new
    ->utf8
    ->pretty(1)
    ->indent(1)
    ->allow_blessed(1)
    ->convert_blessed(1);

my $compact_encoder = JSON::XS
    ->new
    ->utf8
    ->pretty(0)
    ->indent(0)
    ->allow_blessed(1)
    ->convert_blessed(1);

BEGIN {extends 'Catalyst::Controller'; }

# Return an Email::Address if valid, undef otherwise.
#
sub is_email_valid :Private {
    my( $self, $email ) = @_;
    my @addresses = Email::Address->parse( $email );
    return undef if ( $#addresses == -1 );
    return undef unless( nslookup( $addresses[0]->host ) );
    return $addresses[0];
}

# Convert a req->param into a boolean
#
sub boolean :Private {
    my( $self, $value, $default ) = @_;
    
    if ( !defined( $value ) ) {
	return $default;
    } else {
	if ( length( $value ) ) {
	    return 0 if ( $value eq '0' );
	    return 0 if ( $value =~ /[Ff]alse/ );
	    return 1 if ( $value );
	    return 0;
	} else {
	    return 1 if ( $value );
	    return 0;
	}
    }
}

# Create a username from email
#
sub displayname_from_email :Private {
    my( $self, $email ) = @_;
    my @addresses = Email::Address->parse( $email );
    return undef if ( $#addresses == -1 );
    return undef unless( $addresses[0] );
    my $uname = $addresses[0]->user;
    return undef unless( $uname );
    return $uname;
}

# Create a user name automatically
#
sub auto_username :Private {
    my( $self, $c, $email, $prefered ) = @_;
    my @addresses = Email::Address->parse( $email );
    return undef if ( $#addresses == -1 );
    return undef unless( $addresses[0] );
    my $uname = $addresses[0]->user;
    return undef unless( $uname );

    # If username from email is not in use, use it.  Otherwise
    # generate random postfixs until we have one that is not used.
    #
    my $exists;
    $uname = $prefered || $uname;
    my $username = $uname;
    my $post = 123;
    do {
	$exists = $c->model( 'RDS::User' )->find({ displayname => $username });
	if ( $exists ) {
	    $username = $uname . $post;
	    $post += 1;
	}
    } while ( $exists );

    return $username;
}

# Usage:
#
# sub method : Local {
#   my $self = shift; my $c = shift;
#   my $args = $self->parse_args
#      ( $c,
#        [ var1 => default1,
#          var2 => default2,
#        ],
#        @_ );
#
#  $c->log->debug( $args->{var1} );
#
# This method can be used to pull method arguments from multiple places.  Arguments are
# searched for first as positional uri arguments, then form inputs, then json body encodings.
# This allows a caller some flexibility as to how they pass the params.
#
sub parse_args : Private {
    my $self = shift;
    my $c = shift;
    my $defaults = shift;
    my @args = @_;

    my $ret = {};

    # Don't HTML escape these keys.
    my $excluded_keys = {
	'password' => 1,
	'access_token' => 1,
	'summary_options' => 1
    };

    while( my $key = shift @$defaults ) {
	my $def = shift @$defaults;
	my $arg = shift @args;
	if ( $arg ) {
	    $ret->{$key} = $arg;
	}
	elsif ( defined( $c->req->param( $key ) ) ) {
	    if ( $key =~ /\[\]$/ ) {
		my @a = $c->req->param( $key );
		my @result = map { $self->sanitize( $c, $_ ); } @a;
		$ret->{$key} = \@result;
	    }
	    else {
		if ( !exists( $excluded_keys->{$key} ) ) {
		    $ret->{$key} = $self->sanitize( $c, $c->req->param( $key ) );
		} else {
		    $ret->{$key} = $c->req->param( $key );
		}
	    }
	}
	elsif ( defined( $c->{data} ) && defined( $c->{data}->{$key} ) ) {
	    $ret->{$key} = $self->sanitize( $c, $c->{data}->{$key} );
	}
	else {
	    $ret->{$key} = $def;
	}
    }
    return $ret;
}

# Return a where clause suitable for obtaining mediafiles
#
sub where_valid_mediafile :Private {
    my( $self, $isAlbum, $prefix, $only_visible, $only_videos, $status ) = @_;
    $isAlbum = $self->boolean( $isAlbum, 0 );
    $only_visible = $self->boolean( $only_visible, 1 );
    $only_videos = $self->boolean( $only_videos, 1 );
    $prefix  = 'me' unless( defined( $prefix ) );

    my $where = undef;
    if ( $only_videos ) {
	$where = { 
	    $prefix . '.is_album' => $isAlbum,
	    $prefix . '.media_type' => 'original'
	};
    } else {
	$where = { $prefix . '.is_album' => $isAlbum };
    }

    if ( $only_visible ) {
	$where->{$prefix . '.status'} = [ 'visible', 'complete' ];
    }
    if ( defined( $status ) && scalar( @$status ) ) {
	$where->{$prefix . '.status'} = $status;
    }

    return $where;
}

# Return a resultset for media belonging to, and shared to, the logged in user.
#
sub user_media :Private {
    my( $self, $c, $terms, $only_visible, $only_videos, $status ) = @_;
        $only_visible = $self->boolean( $only_visible, 1 );
    $only_videos = $self->boolean( $only_videos, 1 );

    my $user = $c->user->obj;
    $terms = $terms || {};
    $terms->{is_album} = 0;
    if ( $only_videos ) {
	$terms->{'me.media_type'} = 'original';
    }
    $terms->{-and} = [ -or => ['me.user_id' => $user->id, 
			       'media_shares.user_id' => $user->id] ];
    if ( $only_visible ) {
	$terms->{'me.status'} = [ 'visible', 'complete' ];
    }
    if ( defined( $status ) && scalar( @$status ) ) {
	$terms->{'me.status'} = $status;
    }

    my $rs = $c->model( 'RDS::Media' )->search( $terms, {prefetch=>'media_shares'} );
    return $rs;
}

# Use these methods to return from service calls.  They can be used to
# exit the processing chain at any time (they use detach()).
#
sub status_ok : Private {
    my( $self, $c, $entity ) = @_;
    $c->stash->{entity} = $entity;
    $c->res->status( 200 ); # OK
    $c->detach;
}

sub status_created : Private {
    my( $self, $c, $entity, $location ) = @_;
    $c->stash->{entity} = $entity;
    if ( $location ) {
	$c->res->location( $location );
    }
    else {
	$c->res->location( $c->req->uri );
    }
    $c->res->status( 201 ); # CREATED
    $c->detach;
}

sub status_accepted : Private {
    my( $self, $c, $entity, $location ) = @_;
    $c->stash->{entity} = $entity;
    if ( $location ) {
	$c->res->location( $location );
    }
    else {
	$c->res->location( $c->req->uri );
    }
    $c->res->status( 202 ); # ACCEPTED
    $c->detach;
}

sub status_bad_request : Private {
    my( $self, $c, $message, $detail ) = @_;
    $c->stash->{entity} = { error => 1, message => $message };
    $c->stash->{entity}->{detail} = $detail if ( $detail );
#    $c->res->status( 400 ); # BAD REQUEST
    $c->stash->{entity}->{code} = 400;
    $c->res->status( 200 );

    $c->log->error( "BAD REQUEST: " . $message );

    $c->detach;
}

sub status_forbidden : Private {
    my( $self, $c, $message, $detail ) = @_;
    $c->stash->{entity} = { error => 1, message => $message };
    $c->stash->{entity}->{detail} = $detail if ( $detail );
#    $c->res->status( 403 ); # FORBIDDEN
    $c->stash->{entity}->{code} = 403;
    $c->res->status( 200 );

    $c->log->error( "FORBIDDEN: " . $message );

    $c->detach;
}

sub status_unauthorized : Private {
    my( $self, $c, $message, $detail ) = @_;
    $c->stash->{entity} = { error => 1, message => $message };
    $c->stash->{entity}->{detail} = $detail if ( $detail );
#    $c->res->status( 401 ); # NOT AUTHORIZED
    $c->stash->{entity}->{code} = 401;
    $c->res->status( 200 );

    $c->log->error( "NOT AUTHORIZED: " . $message );

    $c->detach;
}

sub status_not_found : Private {
    my( $self, $c, $message, $detail ) = @_;
    $c->stash->{entity} = { error => 1, message => $message };
    $c->stash->{entity}->{detail} = $detail if ( $detail );
#    $c->res->status( 404 ); # NOT FOUND
    $c->stash->{entity}->{code} = 404;
    $c->res->status( 200 );

    $c->log->error( "NOT FOUND: " . $message );

    $c->detach;
}

sub begin :Private {
    my( $self, $c ) = @_;

    # Make the context available to the logger object
    $c->log()->{context} = $c;

    # Check if incoming request content type is json, and if so,
    # if the request has a body, decode it and place it in $c->{data}
    #
    if ( $c->req->content_type eq 'application/json' ) {
	my $bodything = $c->req->body;
	my $body;

	if ( ref( $bodything ) eq 'File::Temp' ) {
	    my @all = <$bodything>;
	    $body = join( '', @all );
	}
	else {
	    $body = $bodything;
	}

	if ( $body && $body ne "" ) {
	    my $ds;
	    eval {
		$ds = $encoder->decode( $body );
	    };
	    if ( $@ ) {
		$self->status_bad_request( $c, $@ );
	    }
	    else {
		$c->{data} = $ds;
	    }
	}
    }
    
}

# Will serialize $c->stash->{entity} into JSON and send application/json
# header, by default.  If $c->stash->{current_view} is set to something,
# then this default behavior is bypassed and the other view is used.
#
# JSONP is returned if 'callback' was passed as an input parameter.  This
# is to support cross-domain accesses from browsers, if needed.
# 
sub end : Private {
   my $self = shift; my $c = shift;
   my $args = $self->parse_args
      ( $c,
        [ callback => undef,
        ],
        @_ );

   # Try to communicate fatal perl exceptions in a more reasonable way.
   #
   if ( @{$c->error} ) {
       my @arr = @{$c->error};
       my @lines = split(/\n/,$arr[0]);
       my $reason = 'unknown';
       while ( $reason = shift @lines ) {
	   chomp $reason;
	   next if ( $reason =~ /^$/ );
	   last;
       }
       $c->stash->{entity} = { error => 1,
			       message => $c->loc( 'Fatal server error' ),
			       detail => $reason };
       $c->clear_errors;

       $c->log->error( "EXCEPTION: $reason" );
   }

    if ( $c->stash->{current_view} ) {
	$c->forward( 'View::' . $c->stash->{current_view} );
    }
    else {
	if ( $c->stash->{entity} ) {
	    if ( $args->{callback} ) {
		$c->res->content_type( 'application/javascript' );
		$c->res->body( $args->{callback} . '(' .
			       $encoder->encode( $c->stash->{entity} ) . ')' );
	    }
	    else {
		$c->res->content_type( 'application/json' );
		$c->res->body( $encoder->encode( $c->stash->{entity} ) );
	    }
	}
    }
}

# Convert a Data::Page object into JSON to send over API calls
#
sub pagerToJson :Private {
    my ( $self, $pager ) = @_;
    return {
	total_entries => $pager->total_entries,
	entries_per_page => $pager->entries_per_page,
	current_page => $pager->current_page,
	entries_on_this_page => $pager->entries_on_this_page,
	first_page => $pager->first_page,
	last_page => $pager->last_page,
	first => $pager->first,
	'last' => $pager->last,
	previous_page => $pager->previous_page,
	next_page => $pager->next_page,
    };
}

# List all available service endpoints by the name you'd use
# to access them via URL.
#
# There is undoubtably a better way to do this.
#
sub endpoints :Local {
    my( $self, $c ) = @_;
    my $meta = $self->meta;

    my @methods;

    for my $subclass ( $meta->subclasses ) {
	my @parts = split( /::/, $subclass );
	my $pname = lc pop @parts;
	my $m = $subclass->meta;
	for my $method ( $m->get_all_methods ) {
	    if ( $method->package_name eq $subclass ) {
		if ( $method->can( 'attributes' ) ) {
		    my @attrs = @{ $method->attributes };
		    for my $name ( @attrs ) {
			if ( $name eq 'Local' ) {
			    push( @methods, $pname . '/' . $method->name );
			}
		    }
		}
	    }
	}
    }

    $self->status_ok( $c, { endpoints => \@methods } );
}

# Common way to send Mandril emails
# Example:
#
#  $self->send_email( $c, {
#    subject => $c->loc( 'Someone has commented on one of your videos.' ),
#    from => {  *** Optional defaults to viblio ***
#      email => 'address',
#      name  => 'name'
#    },
#    to => [{ email => $mf->user->email,
#	      name  => $mf->user->displayname }],
#    template => 'email/commentsOnYourVid.tt',  *** or body => 'text' ***
#    stash => {
#	from => $c->user->obj,
#	commentText => $comment->comment,
#	model => {
#	    media => $published_mf 
#	}
#    } });
#
sub send_email :Local {
    my( $self, $c, $opts ) = @_;

    # This now off loads to a Amazon SQS queue.  The emailer.pl server pops the
    # queue and does the actual sending of email.
    try {
	my $res = $c->model( 'SQS', $c->config->{sqs}->{email} )
	    ->SendMessage( $compact_encoder->encode( $opts ) );
	return undef;
    } catch {
	$c->log->error( "send_email: error: $_" );
	$c->log->debug( $encoder->encode( $opts ) );
	return $_;
    };
}


# Send generic SQS message.
sub send_sqs :Local {
    my( $self, $c, $queue, $opts ) = @_;

    try {
       my $res = $c->model( 'SQS', $c->config->{sqs}->{$queue} )
           ->SendMessage( $compact_encoder->encode( $opts ) );
       return undef;
    } catch {
       $c->log->error( "send_sqs: error: $_" );
       $c->log->debug( $encoder->encode( $opts ) );
       return $_;
    };
}

# Takes an array of email addresses and resolves it
# looking for possible group names in the list.
#
sub expand_email_list :Private {
    my( $self, $c, $list, $except ) = @_;
    my $user = ( $c->user->can( 'obj' ) ? $c->user->obj : $c->user );
    my @list = @$list;
    my @clean = map { $_ =~ s/^\s+//g; $_ =~ s/\s+$//g; $_ } @list;
    my @addrs = ();

    my %groups = map { $_->contact_name => $_ } $user->groups;

    foreach my $email ( @clean ) {
	my $group = $groups{$email};
	if ( $group ) {
	    my @members = $group->contacts;
	    foreach my $member ( @members ) {
		push( @addrs, $member->contact_email )
		    if ( $member->contact_email );
	    }
	}
	else {
	    push( @addrs, $email ) if ( $self->is_email_valid( $email ) );
	}
    }
    my %uniq = map { $_ => 1 } @addrs;

    if ( $except ) {
	foreach my $remove ( @$except ) {
	    delete $uniq{$remove};
	}
    }

    return keys %uniq;
}

sub push_notification :Private {
    my( $self, $c, $token, $options ) = @_;
    if ( $options->{network} eq 'APNS' ) {
	try {
	    my $APNS = Net::APNS->new;
	    my $notifier = $APNS->notify({
		cert   => $c->config->{push}->{apns}->{cert},
		key    => $c->config->{push}->{apns}->{key},
		passwd => $c->config->{push}->{apns}->{password} });
	    $notifier->devicetoken( $token );
	    if ( defined( $options->{message} ) ) {
		$notifier->message( $options->{message} );
	    }
	    if ( defined( $options->{badge} ) ) {
		$notifier->badge( $options->{badge} );
	    }
	    if ( defined( $options->{sound} ) ) {
		$notifier->sound( $options->{sound} );
	    }
	    if ( defined( $options->{custom} ) ) {
		$notifier->custom( $options->{custom} );
	    }
	    $notifier->write;
	} catch {
	    $c->log->error( "Push notification: $_" );
	};
    }
}

# Helper function to speed up the publish operation on mediafiles.
#
# As background, publishing a single mediafile, depending on options,
# can cause several database queries:
#
# A query to get the user_uuid of the owner
# A query to get the assets associated with the media
# A query to get the tags associated with the media
# A query to get the faces associated with the media
#
# Often this method is called in a loop over a particular result set,
# and often that result set has a small number of users and or media
# files.
# 
# This method optimizes things by doing a small number of broad
# queries to formulate a set of optional parameters to the publish
# method that cause it to just use whatever we pass in, and not query
# itself.
#
# Returns an array of results from VA::Mediafile->new->publish,
# possible augmented with an owner key that has the JSON of the user
# owning the JSON if the optional include_owner_json parameter is set.
sub publish_mediafiles :Private {
    my $self = shift;
    my $c = shift;
    my $media = shift;
    my $params = shift;

    # DEBUG - we might want to de-duplicate the inbound media list
    # here.

    # If set to 1, includes all images, if set to a false value,
    # includes none, if set to a non-1 true value it is assumed to be
    # an integer that limits the number of images returned.
    my $include_images = 0;
    if ( exists( $params->{include_images} ) ) {
	if ( looks_like_number( $params->{include_images } ) ) {
	    try { 
		$include_images = int( $params->{include_images} );
	    } catch {
		$c->log->error( "Error converting include_images parameter '$params->{include_images}' to number." );
		if ( $params->{include_images} ) {
		    $include_images = 1;
		}
	    }
	} else {
	    if ( $params->{include_images} ) {
		$include_images = 1;
	    }
	}
    }
    if ( $include_images < 0 ) {
	$c->log->error( "Error - negative value '$params->{include_images}' sent to include_images parameter." );
	$include_images = 1;
    }

    if ( scalar( $media ) == 0 ) {
	return [];
    }

    # media.id -> { tag1 => 1, tag2 => 2, ... }
    my $media_tags = {};
    
    # media.id -> [ list of contact RDS::MediaAssetFeatures ]
    my $contact_features = {};
    
    # media.id -> [ list of requested assets ]
    my $assets = {};

    # media.id -> # of media share rows that exist for this media.
    my $shared = {};

    # user_id -> { uuid => user_uuid, json => RDS::User->TO_JSON }
    my $people = {};

    # We also want a list of the media IDs we're going to publish.
    my $mids = [];

    #$c->log->error( "Step 1", time() );

    # DEBUG - Relocate similar code to this into
    # ...User::visible_media and pass it in as an input variable.
    foreach my $m ( @$media ) {
	my $owner_id = $m->user_id;
	unless ( exists( $people->{$owner_id} ) ) {
	    $people->{$owner_id} = { uuid => $m->user->uuid };
	    if ( $params->{include_owner_json} ) {
		$people->{$owner_id}->{json} = $m->user->TO_JSON;
	    }
	}
	
	push( @$mids, $m->id );
    }

    #$c->log->error( "Step 2", time() );

    my $search = { 'me.media_id' => { -in => $mids } };
    if ( !$include_images ) {
	$search->{'me.asset_type'} = { '!=', 'image' };
    }

    # DEBUG - Relocate this into ...User::visible_media and pass it as
    # an input variable.
    #
    # NOTE: The sort order of images by increasing timecode in the
    # source movie is important to the logic below.
    my @mas = $c->model( 'RDS::MediaAsset' )->search( $search, { order_by => 'me.timecode' } )->all();
    
    # We will handle images sperately because we wish to only return
    # $include_images worth of images per media.
    my %media_images = ();

    foreach my $ma ( @mas ) {
	if ( ( $include_images > 1 ) && ( $ma->{_column_data}->{asset_type} eq 'image' ) ) {
	    if ( exists( $media_images{$ma->media_id} ) ) {
		push( @{$media_images{$ma->media_id}}, $ma );
	    } else {
		$media_images{$ma->media_id} = [ $ma ];
	    }
	} else {
	    if ( exists( $assets->{$ma->media_id} ) ) {
		push( @{$assets->{$ma->media_id}}, $ma );
	    } else {
		$assets->{$ma->media_id} = [ $ma ];
	    }
	}
    }

    # If include images is true and greater than one then we wish to
    # limit the number of returned images to this value.
    if ( $include_images > 1 ) {
	foreach my $mid ( keys( %media_images ) ) {
	    my $image_count = scalar( @{$media_images{$mid}} );

	    if ( $image_count > $include_images ) {
		# Add the first asset.
		if ( exists( $assets->{$mid} ) ) {
		    push( @{$assets->{$mid}}, $media_images{$mid}->[0] );
		} else {
		    $assets->{$mid} = [ $media_images{$mid}->[0] ];
		}
		if ( $include_images > 2 ) {
		    # If we need more than two, pick some evenly
		    # spaced ones out from the middle.

		    # Note: step > 1.
		    my $step = $image_count / ( $include_images - 1 );
		    for ( my $i = 1 ; $i < $include_images - 1 ; $i++ ) {
			push( @{$assets->{$mid}}, $media_images{$mid}->[ int( $i * $step ) ] );
		    }
		}
		# Add the last asset.
		push( @{$assets->{$mid}}, $media_images{$mid}->[-1] );
	    } else {
		# Include everything if image count is less than or
		# equal to the limit.
		if ( exists( $assets->{$mid} ) ) {
		    $assets->{$mid} = [ @{$assets->{$mid}}, @{$media_images{$mid}} ];
		} else {
		    $assets->{$mid} = $media_images{$mid};
		}
	    }
	}
    }

    #$c->log->error( "Step 3", time() );

    if ( $params->{include_tags} ) {
	if ( exists( $params->{media_tags} ) ) {
	    $media_tags = $params->{media_tags};
	} else { 
	    my @mafs = $c->model( 'RDS::MediaAssetFeature' )->search( { 
		'me.media_id' => { -in => $mids },
		-or => [ 'me.feature_type' => 'activity',
			 -and => [ 'me.feature_type' => 'face',
				   'me.contact_id' => { '!=', undef } ] ] } );
	    foreach my $maf ( @mafs ) {
		my $tag = undef;
		if ( $maf->{_column_data}->{feature_type} eq 'face' ) {
		    $tag = 'people';
		} elsif ( $maf->{_column_data}->{feature_type} eq 'activity' ) {
		    $tag = $maf->coordinates;
		}
		if ( defined( $tag ) ) {
		    $media_tags->{$maf->media_id}->{$tag} = 1;
		}
	    }
	}
    }

    #$c->log->error( "Step 4", time() );

    if ( $params->{include_contact_info} ) {
	if ( exists( $params->{media_contact_features} ) ) {
	    $contact_features = $params->{media_contact_features};
	} else {
	    my @mafs = $c->model( 'RDS::MediaAssetFeature' )->search( 
		{ 
		    'me.media_id' => { -in => $mids },
		    'contact.id' => { '!=', undef },
		    'me.feature_type'=>'face',
		    'me.recognition_result' => { -in => [ 'machine_recognized', 'human_recognized', 'new_face' ] } },
		{ prefetch => ['contact', 'media_asset'],
		  group_by => [ 'me.media_id', 'contact.id'] } );
	    foreach my $maf ( @mafs ) {
		if ( exists( $contact_features->{$maf->media_id} ) ) {
		    push( @{$contact_features->{$maf->media_id}},  { 'media_asset' => $maf->media_asset(),
								     'media_asset_feature' => $maf } );
		} else {
		    $contact_features->{$maf->media_id} = [ { 'media_asset' => $maf->media_asset(),
							      'media_asset_feature' => $maf } ];
		}
	    }
	}
    }
    
    #$c->log->error( "Step 5", time() );
    
    if ( $params->{include_shared} ) {
	my @shares = $c->model( 'RDS::MediaShare' )->search(
	    { 'media_id' => { -in => $mids } },
	    { group_by => [ 'me.media_id' ],
	      select => [ 'me.media_id', { count => 'me.id', -as => 'share_count' } ] } );
	foreach my $share ( @shares ) {
	    $shared->{$share->{_column_data}->{media_id}} = $share->{_column_data}->{share_count};
	}
    }

    #$c->log->error( "Step 6", time() );

    my $result = [];

    my $logged_in_user_id = $c->user->id();
    
    foreach my $m ( @$media ) {
	# DEBUG - we are squashing a big params hash here over and
	# over - this clearly works but we should document what we're
	# up to, or make a copy of params.
	$params->{assets} = $assets->{$m->id};
	$params->{owner_uuid} = $people->{$m->user_id}->{uuid};
	
	# DEBUG - what is this doing here - I think it might be broken
	# in the case where we try to pass in some media_tags.
	if ( $params->{include_tags} ) {
	    if ( exists( $media_tags->{$m->id} ) ) {
		$params->{media_tags} = $media_tags->{$m->id};
	    } else {
		$params->{media_tags} = {};
	    }
	}
	
	if ( $params->{include_contact_info} ) {
	    if ( exists( $contact_features->{$m->id} ) ) {
		$params->{features} = $contact_features->{$m->id};
	    } else {
		$params->{features} = [];
	    }
	}
	
	if ( $params->{include_shared} ) {
	    if ( exists( $shared->{$m->id} ) ) {
		$params->{shared} = $shared->{$m->id};
	    } else {
		$params->{shared} = 0;
	    }
	}

	my $hash = VA::MediaFile->new->publish( $c, $m, $params );

	if ( $params->{include_owner_json} ) {
	    $hash->{owner} = $people->{$m->user_id}->{json};
	}
	
	if ( $m->user_id() != $logged_in_user_id ) {
	    $hash->{is_shared} = 1;
	} else {
	    $hash->{is_shared} = 0;
	}
	
	push( @$result, $hash );
    }

    return $result;
}

# Returns the fb_user object - the result of Model::Facebook::fetch( 'me' )
# Also sets session->{fb_token} = the supplied token.
sub validate_facebook_token :Private {
    my( $self, $c, $token ) = @_;

    $token = $c->req->param( 'access_token' ) unless( $token );
    unless( $token ) {
	$c->log->error( "Missing token param for link_facebook_account()" );
	$self->status_bad_request
	    ( $c, 
	      $c->loc("Unable to establish a link to Facebook at this time.") );
    }
    my $fb = $c->model( 'Facebook', $token );
    unless( $fb ) {
	$c->log->error( "Failed to link FB account: token was: " + $token );
	$self->status_bad_request
	    ( $c, 
	      $c->loc("Unable to establish a link to Facebook at this time.") );
    }
    my $fb_user = $fb->fetch( 'me' );
    unless( $fb_user ) {
	$c->log->error( "Facebook fetch(me) failed during FB link" );
	$self->status_bad_request
	    ( $c, 
	      $c->loc("Unable to establish a link to Facebook at this time.") );
    }
    unless( $fb_user->{id} ) {
	$c->log->error( "Facebook user id missing during link" );
	$c->logdump( $fb_user );
	$self->status_bad_request
	    ( $c, 
	      $c->loc("Unable to establish a link to Facebook at this time.") );
    }
    $c->user->obj->update_or_create_related
	( 'links', {
	    provider => 'facebook',
	  });
    my $link = $c->user->obj->links->find({provider => 'facebook'});
    $link->data({
	link => $fb_user->{link},
	access_token => $token,
	id => $fb_user->{id} });
    $link->update; 
    $c->session->{fb_token} = $token;
    
    return $fb_user;
}

# Utility function to make user input for comments, names, tags, etc. safe.
sub sanitize :Private {
    my( $self, $c, $txt ) = @_;

    # Finally, comments can only be 2048 chars in length
    if ( defined( $txt ) ) {
	if ( length( $txt ) > 2048 ) {
	    $txt = substr( $txt, 0, 2047 );
	}
	return CGI::escapeHTML( $txt );
    } else {
	return undef;
    }
}

# Utility function to build a tags information suitable for feeding
# into publish_mediafilesresponse to the UI given a list of media
# items.
#
# Returns an array with the following elements:
#
# media_tags - a hash keyed off media_uuid for passing down to
# publish_mediafiles to eliminate subqueries there.
#
# media_contact_features - a hash keyed off media_id where the value
# is an array ref to an array of { media_asset => MA_OBJECT,
# media_asset_feaute => MAF_OBJECT } hashes, one for each contact in
# this media.
#
sub get_tags :Private {
    my ( $self, $c, $media_list, $datetime_parser ) = @_;

    my $media_tags = {};
    my $media_contact_features = {};

    my $valid_faces = {
	'machine_recognized' => 1,
	'human_recognized' => 1,
	'new_face' => 1
    };

    my $dtf = $datetime_parser;
    if ( !defined( $dtf ) ) {
	$dtf = $c->model( 'RDS' )->schema->storage->datetime_parser;
    }
    my $no_date_date = DateTime->from_epoch( epoch => 0 );

    foreach my $m ( @$media_list ) {

	my $seen_in_media = {};

	foreach my $ma ( $m->media_assets() ) {
	    foreach my $feature ( $ma->media_asset_features() ) {
		my $feature_type = $feature->{_column_data}->{feature_type};
		if ( $feature_type eq 'activity' ) {
		    $media_tags->{ $m->id() }->{ $feature->coordinates() } = 1;
		} elsif ( ( $feature_type eq 'face' ) 
			  and defined( $feature->contact() )
			  and defined( $feature->recognition_result() )
			  and exists( $valid_faces->{ $feature->recognition_result() } ) ) {

		    # We only want at most one feature / image per contact per media.
		    if ( !exists( $seen_in_media->{$m->id()}->{$feature->contact->id()} ) ) {
			$seen_in_media->{$m->id()}->{$feature->contact->id()} = 1;
			
			if ( exists( $media_contact_features->{ $m->id() } ) ) {
			    push( @{$media_contact_features->{ $m->id() }}, { 'media_asset' => $ma,
									      'media_asset_feature' => $feature } );
			} else {
			    $media_contact_features->{ $m->id() } = [ { 'media_asset' => $ma,
									'media_asset_feature' => $feature } ];
			}
		    }
		}
	    }
	}
    }
    return ( $media_tags, $media_contact_features );
}


__PACKAGE__->meta->make_immutable;

1;
