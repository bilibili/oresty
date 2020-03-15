#!/bin/bash
set -e

test -e config || ln -s config_${1:-dev} config

#
# 安装
#
dpkg -i ./install.deb

#
# 配置systemd
#
APPDIR=$PWD
echo """
[Service]
User=root
WorkingDirectory=$APPDIR
ExecStart=/usr/local/oresty/nginx/sbin/nginx -c $APPDIR/nginx.conf -g 'daemon off;'
ExecReload=/usr/local/oresty/nginx/sbin/nginx -c $APPDIR/nginx.conf -s reload
ExecStop=/usr/local/oresty/nginx/sbin/nginx -c $APPDIR/nginx.conf -s stop
[Install]
WantedBy=default.target
""" > oresty.service
systemctl enable $(realpath oresty.service)

test -e .git && {
    test -e .git/hooks/pre-commit || {
        echo '#!/bin/sh
echo v$(git log master --pretty=oneline | wc -l)-$(date +%Y%m%d) > version
git add version' > .git/hooks/pre-commit
        chmod +x .git/hooks/pre-commit
    }
}

echo OK
