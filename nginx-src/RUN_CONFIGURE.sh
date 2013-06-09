tar zxf nginx-1.2.6.tar.gz
cd nginx-1.2.6
wget ftp://ftp.csx.cam.ac.uk/pub/software/programming/pcre/pcre-8.30.tar.gz
tar zxf pcre-8.30.tar.gz
./configure --prefix=/usr \
	    --with-pcre=`pwd`/pcre-8.30 \
	    --conf-path=/etc/nginx/nginx.conf \
	    --error-log-path=/var/log/nginx/error.log \
	    --http-client-body-temp-path=/var/lib/nginx/body \
	    --http-fastcgi-temp-path=/var/lib/nginx/fastcgi \
	    --http-log-path=/var/log/nginx/access.log \
	    --http-proxy-temp-path=/var/lib/nginx/proxy \
	    --http-scgi-temp-path=/var/lib/nginx/scgi \
	    --http-uwsgi-temp-path=/var/lib/nginx/uwsgi \
	    --lock-path=/var/lock/nginx.lock \
	    --pid-path=/var/run/nginx.pid \
	    --with-debug \
	    --with-http_addition_module \
	    --with-http_dav_module \
	    --with-http_gzip_static_module \
	    --with-http_realip_module \
	    --with-http_stub_status_module \
	    --with-http_ssl_module \
	    --with-http_sub_module \
	    --with-sha1=/usr/include/openssl \
	    --with-md5=/usr/include/openssl \
	    --with-mail \
	    --with-mail_ssl_module \
	    --with-http_secure_link_module
make

