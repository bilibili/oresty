local cjson = require 'cjson.safe'
local lup = require 'lib.lup'

local _M = {}

local started = false


local function callback(delay)

    local s = {}
    local val, last = 0
    for _, key in ipairs(ngx.shared.stat:get_keys()) do
        if not ngx.re.match(key, '@', 'jo') then
            val = ngx.shared.stat:get(key) or 0
            s[key] = val
            last = ngx.shared.stat:get(key..'@last') or 0
            s[key..'@delta'] = val - last
            ngx.shared.stat:set(key..'@last', val)
        end
    end
    ngx.update_time()
    s.stat_time = os.date("%Y%m%d_%H%M%S", ngx.time())
    s.stat_delay = delay
    ngx.log(ngx.ERR, cjson.encode(s))
end

function _M.start(before_callback)

    assert(started == false, 'ALREADY_STARTED')
    local delay = 60

    ngx.timer.every(delay, function()
        if before_callback then
            before_callback()
        end
        callback(delay)
    end)
    ngx.log(ngx.ERR, 'STAT_STARTED')

    started = true
end

function _M.set(...)
    ngx.shared.stat:set(...)
end

function _M.incr(...)
    ngx.shared.stat:incr(...)
end

return _M
