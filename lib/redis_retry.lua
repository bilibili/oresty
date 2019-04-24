--
-- User: tangjunxing
-- Date : 2017/08/31
--

local redis = require 'resty.redis'

local _M = {}

function _M.new(host, port, max_retry)
    local instance = setmetatable({}, {
        __index = function(_, method)
            return setmetatable({method = method}, {
                __call = function(_, self, ...)
                    local retry = max_retry or 1
                    local ret, err
                    local red = redis.new()
                    repeat
                        ret = red:connect(host or '127.0.0.1', port or 6379)
                        if ret then
                            ret, err = red[_.method](red, ...)
                            if ret then
                                red:set_keepalive(10000, 10)
                                return ret
                            end
                            red:close()
                        end
                        ngx.log(ngx.ERR, 'REDIS_RETRY_', retry, '_ERROR_', err)
                        retry = retry - 1
                        ngx.sleep(0.05)
                    until retry < 0
                    return nil, err
                end
            })
        end
    })
    return instance
end

return _M
