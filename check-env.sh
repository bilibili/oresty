#!/bin/bash
set -e

dpkg -i ./oresty_1.15.8.1-20190915154915_amd64.deb

mkdir -p /usr/local/oresty/site/ && cp -r ./lualib/ /usr/local/oresty/site/

name=${1:-oresty}
sed "s@_APP_DIR_@$PWD@;s@_NAME_@$name@" oresty.template > $name

echo OK
