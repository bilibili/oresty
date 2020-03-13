--
-- tjx@20200308
--

local prometheus = require 'prometheus'

local _M = {}

local prom = prometheus.init("prometheus_metrics")

local metric_requests = prom:counter("nginx_http_requests_total", "Number of HTTP requests", {"host", "status"})
local metric_latency = prom:histogram("nginx_http_request_duration_seconds", "HTTP request latency", {"host"})
local metric_connections = prom:gauge("nginx_http_connections", "Number of HTTP connections", {"state"})

function _M.get()

    metric_requests:inc(1, {ngx.var.host, ngx.status})
    metric_latency:observe(5, {ngx.var.host})

    metric_connections:set(ngx.var.connections_reading, {"reading"})
    metric_connections:set(ngx.var.connections_waiting, {"waiting"})
    metric_connections:set(ngx.var.connections_writing, {"writing"})

    prom:collect()
end

return _M
