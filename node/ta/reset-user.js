s = require( './lib/storage' )('doesntmatter');
s.clear().then(function(){ process.exit; });
