s = require( './lib/storage' )('settings');
p = require( './lib/storage' )('private');
s.clear().then( function() { 
    p.clear().then( function() {
	process.exit;
    });
});

