var path   = require( 'path' );
var kphyg  = require( 'konphyg' )( path.join( path.dirname(__dirname), 'config' ) );
var config = kphyg( 'ta' ); // app.json

module.exports = config;
