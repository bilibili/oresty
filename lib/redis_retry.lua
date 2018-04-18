--
-- User: tangjunxing
-- Date : 2017/08/31
--
--

local _M

local redis = require 'resty.redis'
local config = require 'config.config'
local cjson = require 'cjson.safe'

-- function _M.new(host, port)
--     return
-- end

local function connect()
    local conn = redis.new()
    local ret, err = conn:connect(config.redis_host, config.redis_port)
    if not ret then
        return nil, 'REDIS_CONN_ERROR_'..err
    end
    conn:set_timeout(10000)
    return conn
end

_M = setmetatable({}, {
    __index = function(_, method)
        return setmetatable({method = method}, {
            __call = function(_, ...)
                local retry = 1
                local conn, ret, err
                while retry > 0 do
                    conn, err = connect()
                    if conn then
                        ret, err = conn[_.method](conn, ...)
                        if ret then
                            conn:set_keepalive(10000, 10)
                            return ret
                        end
                        conn:close()
                    end
                    ngx.log(ngx.ERR, 'REDIS_RETRY_', retry, '_ERROR_', err)
                    retry = retry - 1
                    ngx.sleep(0.05)
                end
                return nil, err
            end
        })
    end
})

function _M.queue(method, args)
    ngx.shared.redis:lpush('_', cjson.encode{
        method = method,
        args = args,
    })
end

function _M.start_queue()
    ngx.timer.at(0, function()
        while not ngx.worker.exiting() do
            local val, err = ngx.shared.redis:rpop('_')
            if val then
                local v = cjson.decode(val)
                if v.method == 'zadd' then
                    _M.zadd(unpack(v.args))
                elseif v.method == 'set' then
                    _M.set(unpack(v.args))
                else
                    ngx.log(ngx.ERR, 'UNKNOWN_REDIS_METHOD')
                end
            else
                ngx.sleep(0.1)
            end
        end
    end)
end

return _M
