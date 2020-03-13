--
-- tjx@20181016
--

local serpent = require 'serpent'
local lup = require 'lib.lup'
require 'resty.core'

local _M = {}

local started = false
local _project = nil

local function _callback(delay)
    ngx.update_time()
    local time = ngx.time()
    local stat_time = os.date("%Y-%m-%dT%H:%M:%S%z", time) -- iso format date
    local s = {
        project = _project,
        stat_time = stat_time,
        stat_delay = delay,
        hostname = lup.gethostname(),
    }
    local val, last, count, last_count = 0, 0, 0, 0, 0
    for _, key in ipairs(ngx.shared.stat:get_keys()) do
        if not ngx.re.match(key, '@', 'jo') then
            val = ngx.shared.stat:get(key) or 0
            s[key] = val
            if type(val) == 'number' then
                last = ngx.shared.stat:get(key..'@last') or 0
                delta = val - last
                s[key..'@delta'] = delta
                ngx.shared.stat:set(key..'@last', val)
                ngx.shared.stat:set(key..'@delta', delta)

                count = ngx.shared.stat:get(key..'@count') or 0
                last_count = ngx.shared.stat:get(key..'@last_count') or 0
                count_delta = count - last_count
                s[key..'@count_delta'] = count_delta
                ngx.shared.stat:set(key..'@last_count', count)
                ngx.shared.stat:set(key..'@count_delta', count_delta)
            end
        end
    end
    local delta, avg = 0
    for k, v in pairs(s) do
        if not ngx.re.match(k, '@', 'jo') and type(v) == 'number' then
            delta = s[k..'@delta']
            if delta then
                count = s[k..'@count_delta']
                if count ~= 0 then
                    avg = delta / count
                    s[k..'@avg'] = avg
                    ngx.shared.stat:set(k..'@avg', avg)
                end
            end
        end
    end
    ngx.log(ngx.ERR, lup.json_encode(s))
end

function _M.get_keys(keys)
    local s = {}
    for _, key in ipairs(keys) do
        for _, suffix in ipairs({'', '@delta', '@last'}) do
            s[key..suffix] = ngx.shared.stat:get(key..suffix)
        end
    end
    return s
end

function _M.start(before_callback, project)

    _project = project or 'UNKNOWN_PROJECT'
    assert(started == false, 'ALREADY_STARTED')
    local delay = 60

    ngx.timer.every(delay, function()
        if before_callback then
            before_callback()
        end
        _callback(delay)
    end)
    ngx.log(ngx.ERR, 'STAT_STARTED')

    started = true
end

function _M.set(self, key, value)
    assert(ngx.re.match(key, '^[a-z0-9_]+$', 'jo'), 'KEY_FORMAT_ERR')
    assert(({number=1, string=1})[type(value)], 'VALUE_FORMAT_ERR')
    if self.name then
        key = self.name..'.'..key
    end
    ngx.shared.stat:set(key, value)
end

function _M.get(self, key)
    assert(ngx.re.match(key, '^[a-z0-9_@]+$', 'jo'), 'KEY_FORMAT_ERR')
    if self.name then
        key = self.name..'.'..key
    end
    return ngx.shared.stat:get(key)
end

function _M.incr(self, key, value, default)
    assert(ngx.re.match(key, '^[a-z0-9_]+$', 'jo'), 'KEY_FORMAT_ERR')
    assert(type(value) == 'number', 'VALUE_FORMAT_ERR')
    if self.name then
        key = self.name..'.'..key
    end
    --
    -- 精度控制在小数点后6位
    --
    ngx.shared.stat:incr(key, value - value % 0.000001, default or 0)
    ngx.shared.stat:incr(key..'@count', 1, 0)
end

function _M.get_metrics()
    local key, metric, name, line, filter = nil, nil, nil, nil, nil
    local keys = ngx.shared.stat:get_keys()
    local ret = table.new(0, 1024)
    for _, key in ipairs(keys) do
        local k = lup.explode('.', key)
        if k[2] then
            metric, name = k[2], k[1]
            filter = serpent.line(ngx.decode_args(name), {comment = false, compact = true})
        else
            metric = k[1]
        end
        ret[#ret + 1] = {
            metric = metric,
            filter = filter,
            value = ngx.shared.stat:get(key) or -1,
        }
    end
    return ret
end

function _M.new(name)
    if name then
        local pattern = '^[a-z0-9_]+=[a-z0-9_]+(&[a-z0-9_]+=[a-z0-9_]+)*$'
        assert(ngx.re.match(name, pattern, 'jo'), 'NAME_FORMAT_ERR')
    end
    return setmetatable({name = name}, {__index = _M})
end

-- "recv": 37432010,
-- "recv@cd": 1164,
-- "recv@delta": 37430944,
-- "sent": 604834877,
-- "sent@cd": 1164,
-- "sent@delta": 604833811,
-- "stat_delay": 60,
-- "stat_time": "2019-09-23T14:24:32+0800",
-- "hostname": "nvm-json-uat-01",
-- "project": "uposgate",

-- nvme_status{device="/dev/nvme0n1",err="critical_composite_temperature_time"} 0
-- nvme_status{device="/dev/nvme0n1",err="critical_warning"} 0
-- nvme_status{device="/dev/nvme0n1",err="media_errors"} 0
-- nvme_status{device="/dev/nvme0n1",err="num_err_log_entries"} 0
-- nvme_status{device="/dev/nvme0n1",err="percentage_used"} 28
-- nvme_status{device="/dev/nvme0n1",err="warning_temperature_time"} 0
-- nvme_status{device="/dev/nvme1n1",err="critical_composite_temperature_time"} 0
-- nvme_status{device="/dev/nvme1n1",err="critical_warning"} 0
-- nvme_status{device="/dev/nvme1n1",err="media_errors"} 0
-- nvme_status{device="/dev/nvme1n1",err="num_err_log_entries"} 0
-- nvme_status{device="/dev/nvme1n1",err="percentage_used"} 19
-- nvme_status{device="/dev/nvme1n1",err="warning_temperature_time"} 0


return _M
