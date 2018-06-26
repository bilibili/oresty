local client = require 'lib.client'
local config = require 'config.config'
local template = require 'resty.template'

local _M = {}

function _M.get(params)

    -- local ret = client.get('http://example.com')

    -- local body = ret.body

    return {
        ni = 'hao'
    }
end

return _M
