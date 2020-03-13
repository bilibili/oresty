--
-- tjx@20200308
--

local client = require 'lib.client'
local config = require 'config.config'

local _M = {}

function _M.get(params)

    -- local ret = client.get('http://example.com')
    -- local body = ret.body

    return {
        time = os.date("%Y-%m-%d_%H:%M:%S", ngx.time()),
        redis_host = config.redis.host,
        message = 'Hello, World!',
        arr = {
            key1 = 'val1',
            key2 = 'val2',
            key3 = 'val3',
        }
    }, 'template/view.html'

end

return _M
