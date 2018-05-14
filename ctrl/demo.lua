local client = require 'lib.client'
local config = require 'config.config'
local template = require 'resty.template'

local _M = {}

function _M.get(params)

    local ret = client.get('http://baidu.com')

    local body = ret.body

    template.render('view.html', {
        message = 'Hello, World!'
    })

    return params
end

return _M
