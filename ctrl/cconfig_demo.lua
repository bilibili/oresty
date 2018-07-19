local client = require 'lib.client'
local cconfig = require 'lib.cconfig'
local config = require 'config.config'
local template = require 'resty.template'

local _M = {}

function _M.get(params)

    local origin = cconfig.get('origin')

    return origin

end

return _M
