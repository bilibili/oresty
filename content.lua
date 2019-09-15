local lup = require 'lib.lup'
local route = require 'lib.route'
local config = require 'config.config'

local r = route.new('/home/tjx/oresty/ctrl/', config.debug)

local params = lup._REQUEST()

local ctrl = params.r or 'home'

local method = params.method or ngx.req.get_method():lower()

r:dispatch(ctrl, method, params)

