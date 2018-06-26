#!/bin/bash
set -e

dpkg -i ./oresty_1.13.6.2-20180626105705_amd64.deb

cp -r ./lualib/ /usr/local/oresty/site/

name=${1:-oresty}
sed "s@_APP_DIR_@$PWD@;s@_NAME_@$name@" oresty.template > $name

echo OK
