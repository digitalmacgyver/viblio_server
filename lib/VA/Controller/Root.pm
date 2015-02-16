package VA::Controller::Root;
use Moose;
use namespace::autoclean;
use JSON::XS ();

my $encoder = JSON::XS
    ->new
    ->utf8
    ->pretty(1)
    ->indent(1)
    ->allow_blessed(1)
    ->convert_blessed(1);

BEGIN { extends 'Catalyst::Controller' }

#
# Sets the actions in this controller to be registered with no prefix
# so they function identically to actions created in MyApp.pm
#
__PACKAGE__->config(namespace => '');

=head1 NAME

VA::Controller::Root - Root Controller for VA

=head1 DESCRIPTION

[enter your description here]

=head1 METHODS

=head2 index

The root page (/)

=cut

sub index :Path :Args(0) {
    my ( $self, $c ) = @_;

    $c->redirect( $c->uri_for( '/home' ) );
}

=head2 default

Standard 404 error page

=cut

sub default :Path {
   my $self = shift; my $c = shift;
   my $callback = $c->req->param( 'callback' );
   my $entity = {
       error => 1,
       message => $c->loc( 'Page not found' ),
       detail => $c->req->path };
   $c->log->error( "Page Not Found" );
   if ( $c->req->header( 'Accept' ) =~ /json/ ) {
       $c->res->status( 200 );
       $c->res->content_type( 'application/json' );
       $c->res->body( $encoder->encode( $entity ) );
   }
   elsif ( $callback ) {
       $c->res->status( 200 );
       $c->res->content_type( 'application/javascript' );
       $c->res->body( $callback . '(' .
		      $encoder->encode( $entity ) . ')' );
   }
   else {
       $c->res->body( $c->req->path . ': ' . $c->loc('Page not found' ));
       $c->res->status(404);
   }
}

=head2 end

Attempt to render a view, if needed.

=cut

sub end : ActionClass('RenderView') {}

=head1 AUTHOR

Andrew Peebles,,,

=head1 LICENSE

This library is free software. You can redistribute it and/or modify
it under the same terms as Perl itself.

=cut

# Note that 'auto' runs after 'begin' but before your actions and that
# 'auto's "chain" (all from application path to most specific class are run)
# See the 'Actions' section of 'Catalyst::Manual::Intro' for more info.
sub auto :Private {
    my ($self, $c) = @_;

    # Initialize i18n
    #
    # Language.  If passed as a param, use it and store it in the
    # session.  Else if in the session, use it.  Else use c->get_locale
    # to guess it.
    #
    my $locale = $c->req->param( 'locale' );
    if ( $locale ) {
	if ( $c->session ) {
	    $c->session->{locale} = $locale;
	}
    }
    if ( $c->session && $c->session->{locale} ) {
	$locale = $c->session->{locale};
    }
    $locale = $c->get_locale unless( $locale );
    $c->languages( $locale ? [ $locale ] : undef );
    
    # Allow unauthenticated users to reach the login page.  This
    # allows unauthenticated users to reach any action in the Login
    # controller.  To lock it down to a single action, we could use:
    #   if ($c->action eq $c->controller('Login')->action_for('index'))
    # to only allow unauthenticated access to the 'index' action we
    # added above.
    #
    if ($c->controller eq $c->controller('Login') ||
	$c->controller eq $c->controller('S') ||
	$c->controller eq $c->controller('Services::NA')) {
	return 1;
    }
    
    # If a user doesn't exist, force login
    if (!$c->user_exists) {
	if ( $c->req->path =~ /^services\// ) {
	    # force a login through services
	    $c->res->code( 200 );
	    $c->stash->{current_view} = 'JSON';
	    $c->stash->{error}  = 1,
	    $c->stash->{message}  = $c->loc("Authentication Failure");
	    $c->stash->{detail} = $c->loc("No session or session expired.");
	    $c->stash->{code} = 401;
	    return 0;
	}
	# Redirect the user to the login page
	$c->response->redirect($c->uri_for('/login'));
	# Return 0 to cancel 'post-auto' processing and prevent use of application
	return 0;
    }
    
    # User found, so return 1 to continue with processing after this 'auto'
    return 1;
}

__PACKAGE__->meta->make_immutable;

1;