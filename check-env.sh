#!/bin/bash
set -e

NAME=${1:-oresty}

test -e config || ln -s config_${1:-dev} config

#
# 安装
#
dpkg -i ./install.deb
mkdir -p /usr/local/${NAME}/site/ && cp -r ./lualib/ /usr/local/${NAME}/site/

#
# 配置systemd
#
cp <(sed "s@_APP_DIR_@$PWD@;s@_NAME_@$NAME@" oresty.service) /etc/systemd/system/${NAME}.service
systemctl enable ${NAME}

test -e .git && {
    test -e .git/hooks/pre-commit || {
        echo '#!/bin/sh
find -name "*.lua" |grep -v /init/| xargs -n1 luajit -bl >/dev/null || exit 1
echo v$(git log master --pretty=oneline | wc -l)-$(date +%Y%m%d) > version
git add version' > .git/hooks/pre-commit
        chmod +x .git/hooks/pre-commit
    }
}

echo OK
