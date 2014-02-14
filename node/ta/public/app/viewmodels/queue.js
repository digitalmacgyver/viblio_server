define(['durandal/app',
	'lib/viblio',
	'knockout'], 
function(app,viblio,ko) {

    var view;
    var files = ko.observableArray([]);

    function _basename( path ) { return path.replace(/.*\//, "").replace( /.*\\/, "" ); }

    var inprogress = 0;

    var total = 0;
    var sent  = 0;
    var BR = 0;
    var BP = 0;

    var start_time = 0;

    var overall_bitrate = ko.observable();
    var overall_percent = ko.observable();
    var overall_size    = ko.observable();

    var total_files_uploaded = ko.observable(0);
    var total_data_uploaded  = ko.observable('0 MB');

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
	inprogress += 1;
	data.basename = _basename( data.filename );
	files.push( data );
	total += data.length;
	if ( start_time == 0 )
	    start_time = new Date().getTime();
	$(view).find( '.vup-stats' ).css( 'visibility', 'visible' );
	showControls();
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
	    //BR += bits_sec;
	    //BP += 1;
	    //overall_bitrate( _formatBitrate( BR/BP ) );
	    overall_bitrate( _formatBitrate( bits_sec ) );
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
	    inprogress -= 1;
	    hideFileControls( data.id );
	}
    });
    
    app.on( 'mq:file:failed', function( data ) {
	var elm = $(view).find('span[uuid="'+data.id+'"]');
	elm.css( 'width', '100%' );
	elm.html( 'FAILED' );	
	inprogress -= 1;
	hideFileControls( data.id );
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
	inprogress -= 1;
	hideFileControls( data.id );
    });
    
    app.on( 'mq:q:drain', function() {
	_getStats();
	if ( inprogress <= 0 ) {
	    app.showMessage( 'All files uploaded.  We will start working on them now.',
			     'Uploaded' ).then( function() {
				 _reset();
				 $(view).find( '.vup-stats' ).css( 'visibility', 'hidden' );
			     });
	    hideControls();
	}
    });

    function _getStats() {
	viblio.api( '/stats' ).then( function( stats ) {
	    total_files_uploaded( stats.total );
	    total_data_uploaded( _formatFileSize( stats.bytes ) );
	});
    }

    function showControls() {
	$(view).find( '.vup-all-control' ).css( 'visibility', 'visible' );
    }

    function hideControls() {
	$(view).find( '.vup-all-control' ).css( 'visibility', 'hidden' );
    }

    function hideFileControls(fid) {
	$(view).find('span[uuid="'+fid+'"]')
	    .parent().parent().find( 'a' )
	    .css( 'visibility', 'hidden' );
    }

    return {
	files: files,
	overall_bitrate: overall_bitrate,
	overall_percent: overall_percent,
	overall_size: overall_size,
	total_files_uploaded: total_files_uploaded,
	total_data_uploaded: total_data_uploaded,

	attached: function( _view ) {
	    view = _view;
	},

	reset: function() {
	    _reset();
	},

	pause: function( me, e ) {
	    var btn = $(e.target);
	    if ( btn.html() == 'Pause All' ) {
		viblio.api( '/pause' ).then(
		    function() {
			files().forEach( function( f ) {
			    f.paused = true;
			    $(view).find('span[uuid="'+f.id+'"]')
				.parent().parent().find( '.icon-pause' )
				.removeClass( 'icon-pause' ).addClass( 'icon-play' );
				
			});
			btn.html( 'Resume All' );
		    },
		    function(err) {
			app.showMessage( err.message );
		    }
		);
	    }
	    else {
		viblio.api( '/resume' ).then(
		    function() {
			files().forEach( function( f ) {
			    f.paused = false;
			    $(view).find('span[uuid="'+f.id+'"]')
				.parent().parent().find( '.icon-play' )
				.removeClass( 'icon-play' ).addClass( 'icon-pause' );
				
			});
			btn.html( 'Pause All' );
		    },
		    function(err) {
			app.showMessage( err.message );
		    }
		);
	    }
	},

	cancel: function( me, e ) {
	    viblio.api( '/cancel' ).then( 
		function() {
		    
		},
		function(err) {
		    app.showMessage( err.message );
		}
	    );
	},

	pause_file: function( file, i ) {
	    if ( file.paused ) {
		$(i.target).css( 'visibility', 'hidden' );
		viblio.api( '/resume', { fid: file.id } ).then( 
		    function() {
			$(i.target).removeClass( 'icon-play' );
			$(i.target).addClass( 'icon-pause' );
			$(i.target).css( 'visibility', 'visible' );
			file.paused = false;
		    },
		    function(err) {
			app.showMessage( err.message );
		    }
		);
	    }
	    else {
		$(i.target).css( 'visibility', 'hidden' );
		viblio.api( '/pause', { fid: file.id } ).then( 
		    function() {
			$(i.target).removeClass( 'icon-pause' );
			$(i.target).addClass( 'icon-play' );
			$(i.target).css( 'visibility', 'visible' );
			file.paused = true;
		    },
		    function(err) {
			app.showMessage( err.message );
		    }
		);
	    }
	},

	cancel_file: function( file, i ) {
	    if ( ! file.cancelled ) {
		viblio.api( '/cancel', { fid: file.id } ).then( 
		    function() {
			$(i.target).parent().siblings().css( 'visibility', 'hidden' );
			$(i.target).parent().css( 'visibility', 'hidden' );
			file.cancelled = true;
		    },
		    function(err) {
			app.showMessage( err.message );
		    }
		);
	    }
	},

	compositionComplete: function( _view ) {
	    _getStats();
	}

    };
});
