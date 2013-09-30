package VA::Controller::Services::Test;
use Moose;
use namespace::autoclean;

BEGIN { extends 'VA::Controller::Services' }

# Just for testing ...
#
sub me :Local {
    my( $self, $c ) = @_;

    if ( $c->{data} ) {
	$c->logdump( $c->{data} );
    }

    $self->status_ok( $c, $c->user->obj );
}

sub argtest :Local {
    my $self = shift; my $c = shift;
    my $args = $self->parse_args
	( $c,
	  [ uid  => '-',
	    zoom => 80,
	    'x'  => '-',
	    'y'  => 90  ],
	  @_ );
    $self->status_ok( $c, { args => $args } );
}

sub email_me :Local {
    my( $self, $c ) = @_;

    my $email = {
	to => $c->user->email,
	from => $c->config->{viblio_return_email_address},
	subject => 'test',
	template => 'test-email.tt',
    };

    $c->stash->{no_wrapper} = 1;

    $c->stash->{email} = $email;

    $c->forward( $c->view('Email::Template') );

    $self->status_ok( $c, 
		      { to => $c->user->email,
			from => $c->config->{viblio_return_email_address},
			subject => $c->loc( 'test' ),
		      } );
}

sub mailchimp :Local {
    my( $self, $c ) = @_;
    
    # https://mandrillapp.com/api/docs/
    my $model = {
	subject => 'Testing Mailchimp',
	from_email => $c->config->{viblio_return_email_address},
	from_name  => 'Viblio',
	to => [{
	    email => $c->user->email,
	    name  => $c->user->displayname }],
	headers => {
	    'Reply-To' => $c->config->{viblio_return_email_address},
	}
    };
    $DB::single = 1;
    $c->stash->{no_wrapper} = 1;
    $c->stash->{model} = $model;
    my $html = $c->view( 'HTML' )->render( $c, 'test-email.tt' );
    $model->{html} = $html;
    # $model->{text} = $text;
    my $res = $c->model( 'Mandrill' )->send( $model );
    $c->logdump( $res );
    if ( $res && $res->{status} && $res->{status} eq 'error' ) {
	$c->logdump( $model );
    }
    $self->status_ok( $c, $res );
}

sub i18n :Local {
    my( $self, $c ) = @_;
    my $name = $c->request->param('name') || $c->loc('Guest');
    # $c->response->content_type('text/plain; charset=utf-8');
    my $message = $c->loc( 'Welcome [_1]!', $name );
    $self->status_ok
	( $c, 
	  { translated => $message,
	    locale => $c->get_locale,
	    language => $c->language(),
	    languages => $c->languages(),
	    installed_languages => $c->installed_languages(),
	  } );
}

sub role_test :Local {
    my( $self, $c ) = @_;
    if ( $c->check_user_roles( 'tester' ) ) {
	$c->log->debug( "** IS A TESTER\n" );
    }
    else {
	$c->log->debug( "** DOES NOT APPEAR TO BE A TESTER\n" );
    }
    $self->status_ok( $c, {} );
}

sub new_video_test :Local {
    my( $self, $c ) = @_;
    my @media = $c->user->media->search({},{prefetch=>'assets'});
    my $uuid;
    foreach my $media ( @media ) {
	if ( my $a = $media->assets->first({asset_type => 'face' }) ) {
	    $uuid = $media->uuid;
	    last;
	}
    }
    if ( $uuid ) {
	$c->req->params({ uid => $c->user->uuid,
			  mid => $uuid,
			  'site-token' => 'maryhadalittlelamb' });
	$c->forward( '/services/na/mediafile_create' );
    }
    else {
	$self->status_bad_request( $c, 'Could not find a media file with faces' );
    }
}


__PACKAGE__->meta->make_immutable;

1;
