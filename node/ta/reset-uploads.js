q = require( './lib/storage' )('q');
q.clear().then( function() {
    process.exit;
});
