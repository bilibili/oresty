#!/bin/bash
#
# tjx@20200313
#

test "$UID" -eq 0 || exec sudo "$0" "$@"

systemctl restart oresty
systemctl status oresty

