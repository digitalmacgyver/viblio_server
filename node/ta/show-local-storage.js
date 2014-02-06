var s = require( './lib/storage' )( 'settings' );
var p = require( './lib/storage' )( 'private' );

console.log( 'Settings:' );
s.json().then( function( json ) {
    console.log( JSON.stringify( json, null, 2 ) ); 
});
p.json().then( function( json ) {
    console.log( JSON.stringify( json, null, 2 ) ); 
});
