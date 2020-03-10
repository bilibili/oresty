--
-- tjx@20200310
--
-- 单例模式封装prometheus.lua
-- knyar/nginx-lua-prometheus: Prometheus metric library for Nginx written in Lua
-- https://github.com/knyar/nginx-lua-prometheus
--

local prometheus = require 'prometheus'
local serpent = require 'serpent'
local lup = require 'lib.lup'

local _M = {
    version = 20200310
}

local shm_prom = ngx.shared.prometheus_metrics
local _prom = nil
local _registered = {}

local function get_metric(_type, name, label_names)
    if not _prom then
        _prom = prometheus.init('prometheus_metrics')
    end
    local metric
    if not _registered[name] then
        metric = _prom[_type](_prom, name, nil, label_names)
        _registered[name] = metric
    else
        metric = _registered[name]
    end
    return metric
end

function _M.gauge(...)
    return get_metric('gauge', ...)
end

function _M.histogram(...)
    return get_metric('histogram', ...)
end

function _M.counter(...)
    return get_metric('counter', ...)
end

function _M.collect()
    _M.gauge('prom_keys_len'):set(#shm_prom:get_keys(0))
    _prom:collect()
end

function _M.flush()
    shm_prom:flush_all()
    return {
        flushed = shm_prom:flush_expired()
    }
end

function _M.metric_data()
    _M.gauge('prom_keys_len'):set(#shm_prom:get_keys(0))
    return _prom:metric_data()
end

function _M.parse_metric_data(metric_data)
    local rows = {}
    for _, line in ipairs(metric_data) do
        local m = ngx.re.match(line, '^([^#][^{]*)([^ ]*) (.*)')
        if m then
            local metric = m[1]
            local value = m[3]
            local labels = nil
            if not lup.empty(m[2]) then
                local d = 'do local _='..m[2]..'; return _;end'
                local ok, copy = serpent.load(d)
                if ok then
                    labels = copy
                end
            end
            rows[#rows + 1] = {
                value = value,
                labels = labels,
                metric = metric,
            }
        end
    end
    return rows
end

return _M
