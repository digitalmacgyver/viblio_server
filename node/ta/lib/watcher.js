var watchr = require( 'watchr' );
var path   = require( 'path' );
var events = require( 'events' );
var Deferred = require( 'promised-io/promise').Deferred;

var Watcher = function() {
    this.watchers = {};
    events.EventEmitter.call( this );
};

// I am an event emitter
Watcher.super_ = events.EventEmitter;
Watcher.prototype = Object.create(events.EventEmitter.prototype, {
    constructor: {
        value: Watcher,
        enumerable: false
    }
});

Watcher.prototype.remove = function( dir ) {
    var self = this;
    if ( self.watchers[dir] ) {
	self.watchers[dir].close();
	delete self.watchers[dir];
    }
}

Watcher.prototype.add = function( dir ) {
    var self = this;
    var dfd  = new Deferred();

    var keys = Object.keys( self.watchers );

    // dir may be below an existing watcher.  if it is,
    // then just ignore this call
    var found = false;
    keys.forEach( function( key ) {
	var regexp = new RegExp( '^'+key );
	if ( dir.match( regexp ) )
	    found = 1;
    });

    if ( found ) {
	self.emit( 'log', 'watcher: already being watched: ' + dir );
	dfd.resolve({});
    }
    else {
	// dir may be above one or more watchers.  find the
	// watchers it is above and remove them.  add this
	// as a new watcher.
	var regexp = new RegExp( '^'+dir );
	var matches = [];
	keys.forEach( function( key ) {
	    if ( key.match( regexp ) ) 
		matches.push( key );
	});
	if ( matches.length ) {
	    self.emit( 'log', 'watcher: replacing [' + matches.join(',') + '] with ' + dir );
	    matches.forEach( function( match ) {
		self.remove( match );
	    });
	}

	self.emit( 'log', 'watcher: adding: ' + dir );
	self._add( dir ).then( function( w ) {
	    dfd.resolve({ dir: dir, matches: matches });
	});
    }
    return dfd.promise;
}

Watcher.prototype._add = function( dir ) {
    var self = this;
    var dfd  = new Deferred();

    watchr.watch({
	path: dir,
	ignoreHiddenFiles: true,
	//interval: (1000 * 20) + 7,
	//catchupDelay: 1000 * 10,
	listeners: {
            error: function(err) {
		self.emit( 'error', err );
            },
            watching: function(err,watcherInstance,isWatching){
		if (err) 
		    self.emit( 'error', err );
		else 
		    self.emit( 'log', 'watcher: watching ' + dir );
            },
            change: function(changeType,filePath,fileCurrentStat,filePreviousStat){
		if ( fileCurrentStat && ! fileCurrentStat.isDirectory() ) {
		    self.emit( 'change', filePath, fileCurrentStat, filePreviousStat );
		}
            }
	},
	next: function(err,watcher) {
            if (err) {
		self.emit( 'error', err );
		dfd.reject( err );
            } else {
		self.watchers[dir] = watcher;
		dfd.resolve( watcher );
	    }
	}
    });
    return dfd.promise;
}

var me = new Watcher();
module.exports = me;
