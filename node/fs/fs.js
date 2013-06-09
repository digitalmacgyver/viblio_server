#!/usr/bin/env node
/*
 * jQuery File Upload Plugin Node.js Example 2.0
 * https://github.com/blueimp/jQuery-File-Upload
 *
 * Copyright 2012, Sebastian Tschan
 * https://blueimp.net
 *
 * Licensed under the MIT license:
 * http://www.opensource.org/licenses/MIT
 *
 * Heavily modified by Andrew Peebles
 */

/*jslint nomen: true, regexp: true, unparam: true, stupid: true */
/*global require, __dirname, unescape, console */

(function (port) {
    'use strict';
    var path = require('path'),
        fs = require('fs'),
        url = require('url'),
        mkdirp = require( 'mkdirp' ),
        // Since Node 0.8, .existsSync() moved from path to fs:
        _existsSync = fs.existsSync || path.existsSync,
        formidable = require('formidable'),
        nodeStatic = require('node-static'),
        imageMagick = require('imagemagick'),
        options = {
            tmpDir: '/opt/fs/tmp',
            publicDir: __dirname + '/public',
            // uploadDir: __dirname + '/public/files',
            uploadDir: '/opt/fs',
	    uid: null, // set in incoming upload form
            uploadUrl: '/fs/',
            maxPostSize: 11000000000, // 11 GB
            minFileSize: 1,
            maxFileSize: 10000000000, // 10 GB
            acceptFileTypes: /.+/i,
            // Files not matched by this regular expression force a download dialog,
            // to prevent executing any scripts in the context of the service domain:
            safeFileTypes: /\.(gif|jpe?g|png)$/i,
            imageTypes: /\.(gif|jpe?g|png)$/i,
            imageVersions: {
                'thumbnail': {
                    width: 80,
                    height: 80
                }
            },
            videoTypes: /\.(flv|mp4|m4v|m3u8|ts|3gp|mov|avi|wmv)$/i,
            videoVersions: {
                'thumbnail': {
                    width: 80,
                    height: 80
                }
            },
            accessControl: {
                allowOrigin: '*',
                allowMethods: 'OPTIONS, HEAD, GET, POST, PUT, DELETE'
            },
            /* Uncomment and edit this section to provide the service via HTTPS:
            ssl: {
                key: fs.readFileSync('/Applications/XAMPP/etc/ssl.key/server.key'),
                cert: fs.readFileSync('/Applications/XAMPP/etc/ssl.crt/server.crt')
            },
            */
            nodeStatic: {
                cache: 3600 // seconds to cache served files
            }
        },
        uploadPath = function() {
	    var dir = options.uploadDir;
	    if ( options.uid )
		dir = options.uploadDir + '/' + options.uid;
	    if ( ! _existsSync( dir ) )
		mkdirp.sync( dir );
	    return dir;
	},
        uploadUrl = function() {
	    if ( options.uid )
		return options.uploadUrl + options.uid + '/'; 
	    else
		return options.uploadUrl;
	},
        removeIfEmpty = function( dir ) {
	    // If the dir is empty, it'll be removed.  If not, this
	    // command will fail, and that's ok.
	    try {
		fs.rmdirSync( dir );
	    } catch(e) {
		// no problem
	    }
	},
        utf8encode = function (str) {
            return unescape(encodeURIComponent(str));
        },
        fileServer = new nodeStatic.Server(options.publicDir, options.nodeStatic),
        nameCountRegexp = /(?:(?: \(([\d]+)\))?(\.[^.]+))?$/,
        nameCountFunc = function (s, index, ext) {
            return ' (' + ((parseInt(index, 10) || 0) + 1) + ')' + (ext || '');
        },
        FileInfo = function (file) {
            this.name = file.name;
            this.size = file.size;
            this.type = file.type;
            this.delete_type = 'DELETE';
        },
        UploadHandler = function (req, res, callback) {
            this.req = req;
            this.res = res;
            this.callback = callback;
        },
        serve = function (req, res) {
            res.setHeader(
                'Access-Control-Allow-Origin',
                options.accessControl.allowOrigin
            );
            res.setHeader(
                'Access-Control-Allow-Methods',
                options.accessControl.allowMethods
            );
            var handleResult = function (result, redirect) {
                    if (redirect) {
                        res.writeHead(302, {
                            'Location': redirect.replace(
                                /%s/,
                                encodeURIComponent(JSON.stringify(result))
                            )
                        });
                        res.end();
                    } else {
			var ct = 'text/plain';
			if ( req.headers.accept )
			    ct = req.headers.accept.indexOf('application/json') !== -1 ?
                            'application/json' : 'text/plain';
                        res.writeHead(200, {
                            'Content-Type': ct
                        });
                        res.end(JSON.stringify(result));
                    }
                },
                setNoCacheHeaders = function () {
                    res.setHeader('Pragma', 'no-cache');
                    res.setHeader('Cache-Control', 'no-store, no-cache, must-revalidate');
                    res.setHeader('Content-Disposition', 'inline; filename="files.json"');
                },
                handler = new UploadHandler(req, res, handleResult);
	    handler.path  = url.parse(req.url).pathname;
	    handler.query = url.parse(req.url, true).query;
	    if ( handler.query && handler.query.uid )
		options.uid = handler.query.uid;
	    else 
		options.uid = null;
            switch (req.method) {
            case 'OPTIONS':
                res.end();
                break;
            case 'HEAD':
            case 'GET':
                if (handler.path === '/') {
                    setNoCacheHeaders();
                    if (req.method === 'GET') {
                        handler.get();
                    } else {
                        res.end();
                    }
                } else {
		    fileServer.serve(req, res);
                }
                break;
            case 'POST':
                setNoCacheHeaders();
                handler.post();
                break;
            case 'DELETE':
		handler.path = path.join( options.uploadUrl, handler.path );
                handler.destroy();
                break;
            default:
                res.statusCode = 405;
                res.end();
            }
        };
    fileServer.respond = function (pathname, status, _headers, files, stat, req, res, finish) {
        if (!options.safeFileTypes.test(files[0])) {
            // Force a download dialog for unsafe file extensions:
            res.setHeader(
                'Content-Disposition',
                'attachment; filename="' + utf8encode(path.basename(files[0])) + '"'
            );
        } else {
            // Prevent Internet Explorer from MIME-sniffing the content-type:
            res.setHeader('X-Content-Type-Options', 'nosniff');
        }
        nodeStatic.Server.prototype.respond
            .call(this, pathname, status, _headers, files, stat, req, res, finish);
    };
    FileInfo.prototype.validate = function () {
        if (options.minFileSize && options.minFileSize > this.size) {
            this.error = 'File is too small';
        } else if (options.maxFileSize && options.maxFileSize < this.size) {
            this.error = 'File is too big';
        } else if (!options.acceptFileTypes.test(this.name)) {
            this.error = 'Filetype not allowed';
        }
        return !this.error;
    };
    FileInfo.prototype.safeName = function () {
        // Prevent directory traversal and creating hidden system files:
        this.name = path.basename(this.name).replace(/^\.+/, '');
        // Prevent overwriting existing files:
        while (_existsSync(uploadPath() + '/' + this.name)) {
            this.name = this.name.replace(nameCountRegexp, nameCountFunc);
        }
    };
    FileInfo.prototype.initUrls = function (req) {
        if (!this.error) {
            var that = this,
                baseUrl = (options.ssl ? 'https:' : 'http:') +
                '//' + req.headers.host + uploadUrl();
            this.url = this.delete_url = baseUrl + encodeURIComponent(this.name);
            Object.keys(options.imageVersions).forEach(function (version) {
                if (_existsSync(
                    uploadPath() + '/' + version + '/' + that.name
                    )) {
                    that[version + '_url'] = baseUrl + version + '/' +
                        encodeURIComponent(that.name);
                }
            });
            Object.keys(options.videoVersions).forEach(function (version) {
                if (_existsSync(
                    uploadPath() + '/' + version + '/' + that.name.replace(/\.[^\.]+$/,'.jpg')
                    )) {
                    that[version + '_url'] = baseUrl + version + '/' +
                        encodeURIComponent(that.name.replace(/\.[^\.]+$/,'.jpg'));
                }
            });
        }
    };
    UploadHandler.prototype.get = function () {
        var handler = this,
            files = [];
        fs.readdir(uploadPath(), function (err, list) {
            list.forEach(function (name) {
                var stats = fs.statSync(uploadPath() + '/' + name),
                    fileInfo;
                if (stats.isFile()) {
                    fileInfo = new FileInfo({
                        name: name,
                        size: stats.size
                    });
                    fileInfo.initUrls(handler.req);
                    files.push(fileInfo);
                }
            });
            handler.callback({files: files});
        });
    };
    UploadHandler.prototype.post = function () {
        var handler = this,
            form = new formidable.IncomingForm(),
            tmpFiles = [],
            files = [],
            map = {},
            counter = 1,
            redirect,
        finish = function ( err, stdout, stderr ) {
                counter -= 1;
                if (!counter) {
                    files.forEach(function (fileInfo) {
                        fileInfo.initUrls(handler.req);
                    });
                    handler.callback({files: files}, redirect);
                }
            };
        form.uploadDir = options.tmpDir;
        form.on('fileBegin', function (name, file) {
            tmpFiles.push(file.path);
            var fileInfo = new FileInfo(file, handler.req, true);
            fileInfo.safeName();
            map[path.basename(file.path)] = fileInfo;
            files.push(fileInfo);
        }).on('field', function (name, value) {
            if (name === 'redirect') {
                redirect = value;
            }
	    if (name === 'uid' ) {
		options.uid = value;
	    }
        }).on('file', function (name, file) {
            var fileInfo = map[path.basename(file.path)];
            fileInfo.size = file.size;
            if (!fileInfo.validate()) {
                fs.unlink(file.path);
                return;
            }
            if (options.imageTypes.test(fileInfo.name)) {
                Object.keys(options.imageVersions).forEach(function (version) {
                    counter += 1;
		});
	    }
            if (options.videoTypes.test(fileInfo.name)) {
                Object.keys(options.videoVersions).forEach(function (version) {
                    counter += 1;
		});
	    }
            fs.renameSync(file.path, uploadPath() + '/' + fileInfo.name);
            if (options.imageTypes.test(fileInfo.name)) {
                Object.keys(options.imageVersions).forEach(function (version) {
                    var opts = options.imageVersions[version];
		    if ( ! _existsSync( uploadPath() + '/' + version ) )
			mkdirp.sync( uploadPath() + '/' + version );
                    imageMagick.resize({
                        width: opts.width,
                        height: opts.height,
                        srcPath: uploadPath() + '/' + fileInfo.name,
                        dstPath: uploadPath() + '/' + version + '/' +
                            fileInfo.name
                    }, finish);
                });
            }
            if (options.videoTypes.test(fileInfo.name)) {
                Object.keys(options.videoVersions).forEach(function (version) {
                    var opts = options.videoVersions[version];
		    if ( ! _existsSync( uploadPath() + '/' + version ) )
			mkdirp.sync( uploadPath() + '/' + version );
		    var oname = fileInfo.name.replace(/\.[^\.]+$/,'.jpg');
		    var cmd = "ffmpegthumbnailer " + 
			" -i '" + uploadPath() + '/' + fileInfo.name + "'" +
			" -o '" + uploadPath() + '/' + version + '/' + oname + "'" +
			" -s " + opts.width +
			" -t 00:00:03 " +
			" -a ";
		    require('child_process').exec( cmd, finish );
                });
            }
        }).on('aborted', function () {
            tmpFiles.forEach(function (file) {
                fs.unlink(file);
            });
        }).on('error', function (e) {
            console.log(e);
        }).on('progress', function (bytesReceived, bytesExpected) {
            if (bytesReceived > options.maxPostSize) {
                handler.req.connection.destroy();
            }
        }).on('end', finish).parse(handler.req);
    };
    UploadHandler.prototype.destroy = function () {
        var handler = this,
            fileName;
        if (handler.path.slice(0, options.uploadUrl.length) === options.uploadUrl) {
            fileName = decodeURIComponent(handler.path.slice( options.uploadUrl.length));
	    try {
		fs.unlinkSync(uploadPath() + '/' + fileName);
	    } catch(e) {
	    }
            Object.keys(options.imageVersions).forEach(function (version) {
		var thumbdir  = path.dirname( uploadPath() + '/' + fileName ) + '/' + version;
		var thumbfile = path.basename( uploadPath() + '/' + fileName );
		try {
                    fs.unlinkSync(thumbdir + '/' + thumbfile);
		} catch( e ) {
		}
		removeIfEmpty(thumbdir );
            });
            Object.keys(options.videoVersions).forEach(function (version) {
		var thumbdir  = path.dirname( uploadPath() + '/' + fileName ) + '/' + version;
		var thumbfile = path.basename( uploadPath() + '/' + fileName.replace(/\.[^\.]+$/,'.jpg') );
		try {
                    fs.unlinkSync(thumbdir + '/' + thumbfile);
		} catch( e ) {
		}
		removeIfEmpty(thumbdir );
            });
	    // if its empty, remove the directory (qp)
	    removeIfEmpty( path.dirname( uploadPath() + '/' + fileName ) );
            handler.callback({success: true});
        } else {
            handler.callback({success: false});
        }
    };
    if (options.ssl) {
        require('https').createServer(options.ssl, serve).listen(port);
    } else {
        require('http').createServer(serve).listen(port);
    }
}(3003));
