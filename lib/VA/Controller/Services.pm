package VA::Controller::Services;
use Moose;
use namespace::autoclean;
use JSON::XS ();
use Email::AddressParser;
use Email::Address;
use Net::Nslookup;
use Try::Tiny;

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
    $value = $default unless( $value );
    return 0 unless( $value );
    return 1 if ( $value eq '1' );
    return 0 if ( $value eq '0' );
    return 1 if ( $value =~ /[Tt]rue/ );
    return 0 if ( $value =~ /[Ff]alse/ );
    return 1;
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

    while( my $key = shift @$defaults ) {
	my $def = shift @$defaults;
	my $arg = shift @args;
	if ( $arg ) {
	    $ret->{$key} = $arg;
	}
	elsif ( defined( $c->req->param( $key ) ) ) {
	    if ( $key =~ /\[\]$/ ) {
		my @a = $c->req->param( $key );
		$ret->{$key} = \@a;
	    }
	    else {
		$ret->{$key} = $c->req->param( $key );
	    }
	}
	elsif ( defined( $c->{data} && defined( $c->{data}->{$key} ) ) ) {
	    $ret->{$key} = $c->{data}->{$key};
	}
	else {
	    $ret->{$key} = $def;
	}
    }
    return $ret;
}

# Return a where claus suitable for obtaining mediafiles
#
sub where_valid_mediafile :Private {
    my( $self, $isAlbum, $prefix ) = @_;
    $isAlbum = 0 unless( defined( $isAlbum ) );
    $prefix  = 'me' unless( defined( $prefix ) );
    return { $prefix . '.is_album' => $isAlbum,
	     -or => [ $prefix . '.status' => 'TranscodeComplete',
		      $prefix . '.status' => 'FaceDetectComplete',
		      $prefix . '.status' => 'FaceRecognizeComplete',
		      $prefix . '.status' => 'visible',
		      $prefix . '.status' => 'complete' ] };
}

# Return a resultset for media belonging to, and shared to, the logged in user.
#
sub user_media :Private {
    my( $self, $c, $terms ) = @_;
    my $user = $c->user->obj;
    $terms = $terms || {};
    $terms->{is_album} = 0;
    $terms->{-and} = [ -or => ['me.user_id' => $user->id, 
			       'media_shares.user_id' => $user->id], 
		       -or => [status => 'TranscodeComplete',
			       status => 'FaceDetectComplete',
			       status => 'FaceRecognizeComplete',
			       status => 'visible',
			       status => 'complete' ]
	];
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

__PACKAGE__->meta->make_immutable;

1;
