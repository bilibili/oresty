#!/bin/bash
set -e

check-oresty()
{
    # apt install -y autoconf libreadline-dev libncurses5-dev libpcre3-dev libssl-dev make
    wget http://bvcstatic.acgvideo.com/openresty-1.13.6.2rc0.tar.gz -O /tmp/openresty-1.13.6.2rc0.tar.gz
    rm -rf /tmp/openresty-1.13.6.2rc0
    tar xvf /tmp/openresty-1.13.6.2rc0.tar.gz -C /tmp/
    pushd /tmp/openresty-1.13.6.2rc0
    echo '
    3928c3928,3929
    <                 if (u->headers_in.status_n == NGX_HTTP_OK
    ---
    >                 if ((u->headers_in.status_n == NGX_HTTP_OK
    >                         || u->headers_in.status_n == NGX_HTTP_PARTIAL_CONTENT)
    ' |patch ./bundle/nginx-1.13.6/src/http/ngx_http_upstream.c
    echo '
    92c92
    <     p = ngx_cpystrn((u_char *) ngx_os_argv[0], (u_char *) "nginx: ",
    ---
    >     p = ngx_cpystrn((u_char *) ngx_os_argv[0], (u_char *) "oresty: ",
    ' |patch ./bundle/nginx-1.13.6/src/os/unix/ngx_setproctitle.c
    echo '
    3708a3709,3718
    >     ngx_str_t name = ngx_string("reqid");
    >     u_char *dst = ngx_pnalloc(r->pool, name.len);
    >     ngx_http_variable_value_t *va = ngx_http_get_variable(r, &name, ngx_hash_strlow(dst, name.data, name.len));
    >     ngx_str_t reqid = ngx_string("-");
    >     if (va != NULL && !va->not_found) {
    >          reqid.data = va->data;
    >          reqid.len = va->len;
    >     }
    >     buf= ngx_snprintf(buf, len, ", reqid: %V", &reqid);
    >     
    ' |patch ./bundle/nginx-1.13.6/src/http/ngx_http_request.c
    ./configure \
        --prefix=/usr/local/oresty \
        --http-fastcgi-temp-path=/tmp/fastcgi_temp \
        --http-uwsgi-temp-path=/tmp/uwsgi_temp \
        --http-scgi-temp-path=/tmp/scgi_temp \
        --http-client-body-temp-path=/tmp/client_body_temp \
        --with-cc-opt=-O2 \
        --with-http_dav_module \
        --with-http_slice_module \
        --with-http_stub_status_module \
        --with-luajit
    make -j`nproc`
    make install
    popd
    declare -f check-oresty>/tmp/check-oresty
}
diff /tmp/check-oresty <(declare -f check-oresty) ||
    check-oresty
cp -r ./lualib/ /usr/local/oresty/site/

name=${1:-oresty}
sed "s@_APP_DIR_@$PWD@;s@_NAME_@$name@" oresty.template > $name

echo OK
