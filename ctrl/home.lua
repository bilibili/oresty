--
-- tjx@20200308
--

local client = require 'lib.client'
local config = require 'config.config'
local template = require 'resty.template'

local _M = {}

function _M.get(params)

    -- local ret = client.get('http://example.com')
    -- local body = ret.body

    template.render('view.html', {
        time = os.date("%Y-%m-%d_%H:%M:%S", ngx.time()),
        redis_host = config.redis.host,
        message = 'Hello, World!',
        arr = {
            key1 = 'val1',
            key2 = 'val2',
            key3 = 'val3',
        }
    })

    return ''
end

return _M
