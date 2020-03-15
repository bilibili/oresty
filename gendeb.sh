
# apt install -y autoconf libreadline-dev libncurses5-dev libpcre3-dev libssl-dev make

# OR_VERSION=1.17.8.1rc0
# NGX_VERSION=1.17.8
OR_VERSION=1.15.8.2
NGX_VERSION=1.15.8
wget https://openresty.org/download/openresty-${OR_VERSION}.tar.gz -O /tmp/openresty-${OR_VERSION}.tar.gz
rm -rf /tmp/openresty-${OR_VERSION}
tar xvf /tmp/openresty-${OR_VERSION}.tar.gz -C /tmp/
cd /tmp/openresty-${OR_VERSION}

echo '
92c92
<     p = ngx_cpystrn((u_char *) ngx_os_argv[0], (u_char *) "nginx: ",
---
>     p = ngx_cpystrn((u_char *) ngx_os_argv[0], (u_char *) "oresty: ",
' |patch ./bundle/nginx-${NGX_VERSION}/src/os/unix/ngx_setproctitle.c

./configure \
    --prefix=/usr/local/oresty \
    --with-cc-opt=-O2 \
    --with-luajit
make -j

checkinstall --pkgrelease=$(date +%Y%m%d%H%M%S) --pkgname=oresty -y
