local client = require 'lib.client'
local config = require 'config.config'
local redis_retry = require 'lib.redis_retry'
local template = require 'resty.template'

local _M = {}

function _M.get(params)

    local red = redis_retry.new(config.redis_host, config.redis_port)
    local ret = ''

    if params.val then
        ret = red:set(params.key, params.val)
    else
        ret = red:get(params.key)
    end

    return ret

end

return _M
