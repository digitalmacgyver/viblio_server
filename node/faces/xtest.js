/*
  Some test code to experiment with translating Intelli-vision XML
  to and from JSON.  I found the xml2json package buggy when going
  to XML, and while the jsontoxml is good at going to XML, it has
  no facility of going to JSON.  So, I have to use both.  The example
  XML came from the Intelli-vision Samples folder.
*/

var parser = require( 'xml2json' );
var jxml   = require( 'jsontoxml' );

var xml = '<userDetails xmlns="http://schemas.datacontract.org/2004/07/RESTFulDemo"><ID>3</ID><mediaURL>http://intellivision2.s3.amazonaws.com/FD_SamplePic.jpg</mediaURL><recognition>1</recognition></userDetails>';

var json = parser.toJson( xml, { object: true } );
console.log( json );

var xout = jxml({
    document: [
	{ name: 'userDetails',
	  attrs: {
	      xmlns: 'http://schemas.datacontract.org/2004/07/RESTFulDemo'
	  },
	  children: {
	      ID: 3,
	      mediaURL: 'http://intellivision2.s3.amazonaws.com/FD_SamplePic.jpg',
	      recognition: 1
	  }
	}
    ]
});
xout = xout.replace( '<document>', '' ).replace( '</document>', '');

console.log( xout );
