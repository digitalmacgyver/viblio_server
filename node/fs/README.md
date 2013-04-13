# File Store

A JSON/JSONP server for uploading files into a local storage directory.  This
is meant to be used with a web server like nginx that can service the
downloads, perhaps in a secure manner.

JSON is returned from these endpoints, or JSONP if a "callback=" parameter
is passed.

# Uploads

The endpoint is /upload.  This is a POST and is expected to be initiated
with a multipart/form-data style post request.  The expected file field
name is "upload"; for example:

'''
<input type="file" name="upload" />
'''

This endpoint can also handle multiple file uploads in the same request:

'''
<input type="file" name="upload" multiple="multiple" />
'''

The JSON (or JSONP) response for a single file upload would be something
like:

'''js
{
  "path": "/fs/c4141282f8bd08410376ce37990fb8dc.gif",
  "name": "xlogo_bg.gif",
  "mimetype": "image/gif",
  "size": 3316
}
'''

and for a mulitple file upload:

'''js
{
  "files": [
    {
      "path": "/fs/c4141282f8bd08410376ce37990fb8dc.gif",
      "name": "xlogo_bg.gif",
      "mimetype": "image/gif",
      "size": 3316
    },
    {
      "path": "/fs/425df8bfa695d198f93066e850e5a207.gif",
      "name": "xlogo_bg.gif",
      "mimetype": "image/gif",
      "size": 3316
    }
  ]
}
'''

The dirname for "path" is the value set in the fs.json file for
**body_parser_options.uploadDir**.

# Deletions

To delete a previously uploaded file, call /delete with "path" equal to
a "path" that was previously returned from an /upload.  If the deletion
is successful, you will get back:

'''js
{
  "success": true
}
'''

Otherwise you will get a 404 error response if the file was not found
or a 500 if there was a server problem.

# Downloads

This server does not do downloads.  Downloads are expected to
be handled statically by a frontend web server like nginx. An
example nginx configuration:

In this simple example, nginx is a frontend that runs on port
80 and directs requests to this node server running on port 3000.
The uploadDir has been set to /opt/uploads, and nginx will server
those files.

'''
server {
       listen           80;
       server_name      localhost;

       location / {
                proxy_set_header X-Real-IP  $remote_addr;
                proxy_set_header Host $host;
                proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
                proxy_pass http://127.0.0.1:3000;                       
       }

       # Store files in /tmp/fs.  http://server/$path.
       location /fs {
                root /tmp;
                expires 0;
                access_log off;
       }
}
'''

You can use a module in nginx to secure the download directory (and maybe even the upload
and delete endpoints).  You need to build a custom nginx binary for this "secure link"
feature.  See ./nginx/src/RUN_CONFIGURE.  Then you need a configuration file like this:

'''js
server {
       listen           80;
       server_name      localhost;

       location / {
                proxy_set_header X-Real-IP  $remote_addr;
                proxy_set_header Host $host;
                proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
                proxy_pass http://127.0.0.1:3000;                       
       }

       location /fs {
                root /tmp;
                expires 0;
                access_log off;

		secure_link $arg_st,$arg_e;
		secure_link_md5 mysecret$uri$arg_e;

		## If the hash is incorrect then $secure_link is a null string.
    		if ($secure_link = "") {
        	    return 403;
    		}
 
		## The current local time is greater than the specified expiration time.
                if ($secure_link = "0") {
        	    return 403;
    		}
       }
}
'''

Look at ./gen-secure-url.pl for an example in perl how to generate the secure urls.
