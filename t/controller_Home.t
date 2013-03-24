use strict;
use warnings;
use Test::More;


use Catalyst::Test 'VA';
use VA::Controller::Home;

ok( request('/home')->is_success, 'Request should succeed' );
done_testing();
