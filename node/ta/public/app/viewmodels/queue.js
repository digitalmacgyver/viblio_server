define(['durandal/app',
	'lib/viblio',
	'knockout'], 
function(app,viblio,ko) {

    var view;
    var files = ko.observableArray([]);

    function _basename( path ) { return path.replace(/.*\//, "").replace( /.*\\/, "" ); }

    var total = 0;
    var sent  = 0;
    var BR = 0;
    var BP = 0;

    var start_time = 0;

    var overall_bitrate = ko.observable();
    var overall_percent = ko.observable();
    var overall_size    = ko.observable();

    function _reset() {
	files.removeAll();
	total = 0; sent = 0;
	BR = 0; BP = 0;
	overall_bitrate( '0' );
	overall_percent( '0%' );
	overall_size( '0 / 0' );
	start_time = 0;
    }
    _reset();

    function _formatFileSize(bytes) {
        if (typeof bytes !== 'number') {
            return '';
        }
        if (bytes >= 1000000000) {
            return (bytes / 1000000000).toFixed(2) + ' GB';
        }
        if (bytes >= 1000000) {
            return (bytes / 1000000).toFixed(2) + ' MB';
        }
        return (bytes / 1000).toFixed(2) + ' KB';
    };

    function _formatBitrate(bits) {
        if (typeof bits !== 'number') {
            return '';
        }
        if (bits >= 1000000000) {
            return (bits / 1000000000).toFixed(2) + ' Gbit/s';
        }
        if (bits >= 1000000) {
            return (bits / 1000000).toFixed(2) + ' Mbit/s';
        }
        if (bits >= 1000) {
            return (bits / 1000).toFixed(2) + ' kbit/s';
        }
        return bits.toFixed(2) + ' bit/s';
    };
    
    function _formatPercentage(floatValue) {
        return (floatValue * 100).toFixed(2) + ' %';
    };

    function _add( data ) {
	data.basename = _basename( data.filename );
	files.push( data );
	total += data.length;
	if ( start_time == 0 )
	    start_time = new Date().getTime();
	$(view).find( '.vup-stats' ).css( 'visibility', 'visible' );
    }

    app.on( 'mq:file:add', function( data ) {
	_add( data );
    });

    app.on( 'mq:file:progress', function( data ) {
	var pct = Math.floor( (data.offset / data.length) * 100 );
	var elm = $(view).find('span[uuid="'+data.id+'"]');
	if ( elm.length == 0 ) {
	    _add( data );
	}
	else {
	    elm.css( 'width', pct+'%' );
	    elm.html( pct+'%' );

	    if ( ! elm.data( 'last' ) ) elm.data( 'last', 0 );

	    sent += ( data.offset - elm.data( 'last' ) );
	    elm.data( 'last', data.offset );

	    var end_time = new Date().getTime();
	    var bits_sec = (sent * 8) / ( (end_time/1000) - (start_time/1000) );
	    BR += bits_sec;
	    BP += 1;
	    overall_bitrate( _formatBitrate( BR/BP ) );
	    overall_percent( _formatPercentage( sent / total ) );
	    overall_size( _formatFileSize( sent  ) + '/' + 
			  _formatFileSize( total ) );
	}
    });

    app.on( 'mq:file:done', function( data ) {
	if ( ! (data.paused || data.cancelled) ) {
	    var elm = $(view).find('span[uuid="'+data.id+'"]');
	    elm.css( 'width', '100%' );
	    elm.html( 'DONE' );	
	}
    });
    
    app.on( 'mq:file:failed', function( data ) {
	var elm = $(view).find('span[uuid="'+data.id+'"]');
	elm.css( 'width', '100%' );
	elm.html( 'FAILED' );	
    });
    
    app.on( 'mq:file:retry', function( data ) {
	var elm = $(view).find('span[uuid="'+data.id+'"]');
	elm.html( 'Retrying...' );	
    });
    
    app.on( 'mq:file:paused', function( data ) {
	var elm = $(view).find('span[uuid="'+data.id+'"]');
	elm.html( 'paused' );	
    });
    
    app.on( 'mq:file:cancelled', function( data ) {
	var elm = $(view).find('span[uuid="'+data.id+'"]');
	elm.css( 'width', '100%' );
	elm.html( 'CANCELLED' );	
    });
    
    app.on( 'mq:q:drain', function() {
	app.showMessage( 'All files uploaded.  We will start working on them now.',
			 'Uploaded' ).then( function() {
			     _reset();
			     $(view).find( '.vup-stats' ).css( 'visibility', 'hidden' );
			 });
			 
    });

    return {
	files: files,
	overall_bitrate: overall_bitrate,
	overall_percent: overall_percent,
	overall_size: overall_size,

	attached: function( _view ) {
	    view = _view;
	},

	reset: function() {
	    _reset();
	},

	pause_file: function( file, i ) {
	    if ( file.paused ) {
		viblio.api( '/resume', { fid: file.id } ).then( 
		    function() {
			$(i).removeClass( 'icon-play' );
			$(i).addClass( 'icon-pause' );
			file.paused = false;
		    },
		    function(err) {
			app.showMessage( err.message );
		    }
		);
	    }
	    else {
		viblio.api( '/pause', { fid: file.id } ).then( 
		    function() {
			$(i).removeClass( 'icon-pause' );
			$(i).addClass( 'icon-play' );
			file.paused = true;
		    },
		    function(err) {
			app.showMessage( err.message );
		    }
		);
	    }
	},

	cancel_file: function( file, i ) {
	    viblio.api( '/cancel', { fid: file.id } ).then( 
		function() {
		    file.cancelled = true;
		},
		function(err) {
		    app.showMessage( err.message );
		}
	    );
	},

    };
});
