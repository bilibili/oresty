local client = require 'lib.client'
local config = require 'config.config'
local redis_client = require 'lib.redis_client'
local template = require 'resty.template'

local _M = {}

function _M.get(params)

    local red = redis_client.new(config.redis)
    local ret = ''

    if params.val then
        ret = red:set(params.key, params.val)
    else
        ret = red:get(params.key)
    end

    return ret

end

return _M
