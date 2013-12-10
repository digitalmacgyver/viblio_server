/*
  uh - Uploader Health monitor

  Actually, this program can monitor any web endpoint by periodically doing a request.
  If there are timeouts or errors (non-200) returned from the request, this failure
  count is sent to Amazon CloudWatch where alarms could be set up.

  The behavior of this program is dictated by configuration located in package.json:

  monitor_endpoint:      The endpoint to "ping", ex. https://viblio.com/files
  monitor_method:        The HTTP method to use, ex. OPTIONS
  cloudwatch_namespace:  The cloudwatch metric namespace, ex. Viblio/Uploader
  cloudwatch_metricname: The metric name, ex. "ping"
  cloudwatch_unit:       The metric unit, ex. "Count"
  dimension_name:        The metric dimension name, ex. "Server"
  dimension_value:       The metric dimension value, ex. "prod"
  ping_interval:         The interval in seconds to perform the request, ex. 30
  ping_timeout:          The timeout in seconds to wait for a response, ex. 5
  reporting_interval:    The interval in seconds to report to Amazon, ex. 60

  The Amazon credencials AWS_ACCESS_KEY_ID and AWS_SECRET_ACCESS_KEY must
  be set in the environment before running this program.

  IMPORTANT!! 
  AWS_CLOUDWATCH_HOST=monitoring.us-west-2.amazonaws.com MUST ALSO BE SET
  in the environment, in order for the data to make it into the correct
  region!
  
  This program runs forever.  It could be fired at boot time via init.d
  script.
*/
var request = require( "request" );
var util = require( "util" );

var config = require( "./package.json" );

var REST = require('node-cloudwatch');
var cw   = new REST.AmazonCloudwatchClient();

var failure_count = 0;

if ( ! process.env[ 'AWS_ACCESS_KEY_ID' ] ||
     ! process.env[ 'AWS_SECRET_ACCESS_KEY' ] ) {
    console.log( 'AWS_ACCESS_KEY_ID and/or AWS_SECRET_ACCESS_KEY are missing from the environment.' );
    process.exit(1);
}

var tmr;
function ping() {
    request({
	uri: config.monitor_endpoint,
	method: config.monitor_method,
	timeout: config.ping_timeout * 1000,
	followRedirect: false
    }, function(error, response, body) {
	if ( error && error.code == 'ETIMEDOUT' ) {
	    console.log( 'timeout' );
	    failure_count += 1;
	}
	else {
	    console.log( response.statusCode );
	    if ( response.statusCode != 200 )
		failure_count += 1;
	}
	tmr = setTimeout( ping, config.ping_interval * 1000 );
    });
}

tmr = setTimeout( ping, config.ping_interval * 1000 );
setInterval( function() {
    var params = {};
    params['Namespace'] =  config.cloudwatch_namespace;
    params['MetricData.member.1.MetricName'] =  config.cloudwatch_metricname;
    params['MetricData.member.1.Unit'] =  config.cloudwatch_unit;
    params['MetricData.member.1.Value'] =  failure_count.toString();
    params['MetricData.member.1.Dimensions.member.1.Name'] =  config.dimension_name;
    params['MetricData.member.1.Dimensions.member.1.Value'] =  config.dimension_value;
    console.log( util.inspect( params ) );
    cw.request('PutMetricData', params, function (response) {
	console.log(failure_count, JSON.stringify(response));
	failure_count = 0; // reset for the next interval
    });
}, config.reporting_interval * 1000 );

