/*
  Usage:

  var iv = require( "./lib/intellivision" );
  var client = iv.createClient({});
  var uid = client.authenticate();
*/

var xml2json = require( 'xml2json' );
var json2xml = require( 'jsontoxml' );
var url      = require( 'url' );
var qs       = require('querystring');

function IVClient( options ) {
    this.userId = 3;
    this.options = options = options || {};
    this.baseUrl = this.options.url || "http://71.6.45.227/FDFRRstService/RestService.svc";
};
exports.IVClient = IVClient;

IVClient.prototype.authenticate = function() {
    var self = this;

    // Does nothing now, but will do the required authentication
    // with Intelli-vision, and get the userId and whatever else
    // is needed for subsequent communication.

    return self.userId;
};

IVClient.prototype.analyzeMedia = function( mediaUrl, callback ) {
    var self = this;

    // Create the XML for posting
    var xml = json2xml({
	document: [
	    { name: 'userDetails',
	      attrs: {
		  xmlns: 'http://schemas.datacontract.org/2004/07/RESTFulDemo'
	      },
	      children: {
		  ID: self.userId,
		  mediaURL: mediaUrl.replace(/&/g, '&amp;'),
		  recognition: 1
	      }
	    }
	]
    });
    xml = xml.replace( '<document>', '' ).replace( '</document>', '');
    
    // Post it
    self.post( '/AnalyzeFaces', xml, function( res ) {
	callback( res );
    });
};

IVClient.prototype.retriveFaces = function( frame, callback ) {
    var self = this;
    self.get( '/RetrieveFaces', { FileId: frame }, callback );
};

IVClient.prototype.post = function( endpoint, body, callback ) {
    var self = this;

    var http = require( 'http' );
    if ( url.parse( self.baseUrl ).protocol == 'https:' )
        http = require( 'https' );

    var options = {
	host: url.parse( self.baseUrl ).host,
	path: url.parse( self.baseUrl ).path + endpoint,
	method: 'POST',
	headers: {
	    'Content-Type': 'application/xml',
	    'Content-Length': body.length
	}
    };
    console.log( options );
    console.log( body );
    var request = http.request( options, function( response ) {
	response.setEncoding( 'utf8' );
	var ret = '';
	response.on( 'data', function( chunk ) {
	    ret += chunk;
	});
	response.on( 'error', function(e) {
	    callback( { error: e.message } );
	});
	response.on( 'end', function() {
	    var json = {};
	    if ( ret ) {
		console.log( ret );
		try {
		    json = xml2json.toJson( ret, { object: true } );
		    callback( json );
		} catch(e) {
		    callback( { error: e.message } );
		}
	    }
	});
    });
    request.write( body );
    request.end();
};    

IVClient.prototype.get = function( endpoint, params, callback ) {
    var self = this;

    var q = qs.stringify( params );
    if ( q != '' )
	endpoint += '?' + q;

    var http = require( 'http' );
    if ( url.parse( self.baseUrl ).protocol == 'https:' )
        http = require( 'https' );

    var options = {
	host: url.parse( self.baseUrl ).host,
	path: url.parse( self.baseUrl ).path + endpoint,
	method: 'GET'
    };
    console.log( options );
    var request = http.request( options, function( response ) {
	response.setEncoding( 'utf8' );
	var ret = '';
	response.on( 'data', function( chunk ) {
	    ret += chunk;
	});
	response.on( 'error', function(e) {
	    callback( { error: e.message } );
	});
	response.on( 'end', function() {
	    var json = {};
	    if ( ret ) {
		try {
		    json = xml2json.toJson( ret, { object: true } );
		    callback( json );
		} catch(e) {
		    callback( { error: e.message } );
		}
	    }
	});
    }).end();
};    

exports.createClient = function( options ) {
    return new IVClient( options );
};
