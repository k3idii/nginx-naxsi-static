#!/usr/bin/env bash

NB_PROC=$(grep -c ^processor /proc/cpuinfo)

NGINX_PREFIX="/etc/nginx/"



# names of latest versions of each package
NGINX_VERSION=1.22.0

VERSION_NGINX=nginx-$NGINX_VERSION
VERSION_LIBRESSL=libressl-2.8.1
VERSION_PCRE=pcre-8.44
NAXSI_VER=1.3

NGINX_DIR="${NGINX_VERSION}"
LIBRESSL_DIR="${VERSION_LIBRESSL}"
PCRE_DIR="${VERSION_PCRE}"
NAXSI_DIR="naxsi-${NAXSI_VER}"


NGINX_TARBALL="${VERSION_NGINX}.tar.gz"
PCRE_TARBALL="${VERSION_PCRE}.tar.gz"
LIBRESSL_TARBALL="$VERSION_LIBRESSL.tar.gz"
NAXSI_TARBALL="$NAXSI_VER.tar.gz"


# URLs to the source directories
SOURCE_LIBRESSL="https://ftp.openbsd.org/pub/OpenBSD/LibreSSL/${LIBRESSL_TARBALL}"
#SOURCE_PCRE="ftp://ftp.csx.cam.ac.uk/pub/software/programming/pcre/"
SOURCE_PCRE="https://ftp.exim.org/pub/pcre/${PCRE_TARBALL}"
SOURCE_NGINX="http://nginx.org/download/${NGINX_TARBALL}"
SOURCE_NAXSI="https://github.com/nbs-system/naxsi/archive/${NAXSI_TARBALL}"


#export SOURCE_RTMP=https://github.com/arut/nginx-rtmp-module.git
#export SOURCE_PAGESPEED=https://github.com/pagespeed/ngx_pagespeed/archive/
 
# clean out any files from previous runs of this script
#rm -rf build
export BUILDPATH=$(pwd)/build
mkdir ${BUILDPATH}

# proc for building faster

# ensure that we have the required software to compile our own nginx
# sudo apt-get -y install curl wget build-essential libgd-dev libgeoip-dev checkinstall git
 

# grab the source files
echo " === Download sources === "
ls -la 

if [ ! -f ${BUILDPATH}/$PCRE_TARBALL     ]; then  wget -P ${BUILDPATH} $SOURCE_PCRE;      fi 
if [ ! -f ${BUILDPATH}/$LIBRESSL_TARBALL ]; then  wget -P ${BUILDPATH} $SOURCE_LIBRESSL;  fi
if [ ! -f ${BUILDPATH}/$NGINX_TARBALL    ]; then  wget -P ${BUILDPATH} $SOURCE_NGINX;     fi 
if [ ! -f ${BUILDPATH}/$NAXSI_TARBALL    ]; then  wget -P ${BUILDPATH} $SOURCE_NAXSI;     fi

#wget -P ./build $SOURCE_PAGESPEED$VERSION_PAGESPEED.tar.gz
#wget -P ./build https://dl.google.com/dl/page-speed/psol/${NPS_VERSION}.tar.gz
#git clone $SOURCE_RTMP ./build/rtmp



echo "=== Extract Packages === "

cd ${BUILDPATH}

if [ ! -d $NGINX_DIR ];   then tar xzf $NGINX_TARBALL;    fi
if [ ! -d $LIBRESSL_DIR]; then tar xzf $LIBRESSL_TARBALL; fi 
if [ ! -d $PCRE_DIR ];    then tar xzf $PCRE_TARBALL;     fi
if [ ! -d $NAXSI_DIR ];   then tar xzf $NAXSI_TARBALL;    fi

#tar xzf $VERSION_PAGESPEED.tar.gz
#tar xzf ${NPS_VERSION}.tar.gz -C ngx_pagespeed-${NPS_VERSION}-beta

cd ../



# set where LibreSSL and nginx will be built

export STATICLIBSSL=${BUILDPATH}/${VERSION_LIBRESSL}
 

# build static LibreSSL
echo "Configure & Build LibreSSL"
cd ${STATICLIBSSL}
./configure LDFLAGS=-lrt --prefix=${STATICLIBSSL}/.openssl/ && make install-strip -j ${NB_PROC}


# build nginx, with various modules included/excluded
echo "Configure & Build Nginx"
cd ${BUILDPATH}/${VERSION_NGINX}

#echo " > make out dir"
#mkdir -p ${BUILDPATH}/nginx

NGINX_PREFIX="/etc/nginx"
NGINX_CONFIG="${NGINX_PREFIX}/nginx.conf"
NGINX_VAR="/tmp/nginx/"
NGINX_LOG="/var/log/nginx/"

echo " > Confugure "
./configure  \
 --with-openssl=${STATICLIBSSL} \
 --with-ld-opt="-lrt"  \
 --prefix=${NGINX_PREFIX} \
 --conf-path=${NGINX_CONFIG} \
 --error-log-path=${NGINX_LOG}/error.log \
 --http-log-path=${NGINX_LOG}/access.log \
 --pid-path=${NGINX_VAR}/nginx.pid \
 --lock-path=${NGINX_VAR}/nginx.lock \
 --http-client-body-temp-path=${NGINX_VAR}/body \
 --http-fastcgi-temp-path=${NGINX_VAR}/fastcgi \
 --http-proxy-temp-path=${NGINX_VAR}/proxy \
 --http-scgi-temp-path=${NGINX_VAR}/scgi \
 --http-uwsgi-temp-path=${NGINX_VAR}/uwsgi \
 --with-pcre=${BUILDPATH}/${VERSION_PCRE} \
 --with-http_ssl_module \
 --with-http_v2_module \
 --with-file-aio \
 --with-ipv6 \
 --with-http_gzip_static_module \
 --with-http_stub_status_module \
 --without-mail_pop3_module \
 --without-mail_smtp_module \
 --without-mail_imap_module \
 --with-debug \
 --with-pcre-jit \
 --with-http_stub_status_module \
 --with-http_realip_module \
 --with-http_auth_request_module \
 --with-http_addition_module \
 --with-http_gzip_static_module \
 --add-module=${BUILDPATH}/${NAXSI_DIR}/naxsi_src/ 
 --with-cc-opt="-O2 -static -fPIC -lpthread  -static-libstdc++ -static-libgcc"    \
 --with-ld-opt="-static -static-libgcc -static-libstdc++"  

 #--add-dynamic-module=${BUILDPATH}/${NAXSI_DIR}/naxsi_src/ 
# --add-module=$BUILDPATH/rtmp
# --with-http_image_filter_module \
 #--with-http_geoip_module \
 #--add-module=$BUILDPATH/ngx_pagespeed-${NPS_VERSION}-beta




touch $STATICLIBSSL/.openssl/include/openssl/ssl.h

make -j $NB_PROC 



cp build/nginx-1.22.0/objs/nginx ./


