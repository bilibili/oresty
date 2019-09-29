#!/bin/bash
set -e

test -e config || ln -s config_${1:-dev} config

dpkg -i ./install.deb

NAME=${1:-oresty}

mkdir -p /usr/local/${NAME}/site/ && cp -r ./lualib/ /usr/local/${NAME}/site/

install <(sed "s@_APP_DIR_@$PWD@;s@_NAME_@$name@" init.template) /etc/init.d/${NAME}

echo OK
