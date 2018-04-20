local client = require 'lib.client'
local lup = require 'lib.lup'

local ret = client.get('http://baidu.com')

lup.var_dump(ret)
