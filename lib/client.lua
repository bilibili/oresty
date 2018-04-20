--
-- User: tangjunxing
-- Date : 2017/08/31
--

local http = require 'resty.http'
local cjson = require 'cjson.safe'

local _M = {
    version = 171130
}

_M = setmetatable({version = 171130}, {
    __index = function(_, method)
        return setmetatable({}, {
            __call = function(_, ...)
                return _M.request(method, ...)
            end
        })
    end
})

local function get_curl(method, arg_url, args)
    local cmds = {}
    local query = ''
    args = args or {}
    for k, v in pairs(args) do
        if k == 'query' then
            query = '?'..ngx.encode_args(v)
        elseif k == 'headers' then
            for header, header_val in pairs(v) do
                cmds[#cmds+1] = '-H "'..header..': '..header_val..'"'
            end
        elseif k == 'proxy' then
            cmds[#cmds+1] = " -x"..v
        elseif k == 'body' then
            cmds[#cmds+1] = '-d \''..v..'\''
        elseif k == 'json' then
            cmds[#cmds+1] = '-H "Content-Type: application/json"'
            cmds[#cmds+1] = '-d \''..cjson.encode(v)..'\''
        elseif k == 'form_params' then
            cmds[#cmds+1] = '-H "Content-Type: application/x-www-form-urlencoded"'
            cmds[#cmds+1] = '-d '..ngx.encode_args(v)
        end
    end
    return 'curl -X'..string.upper(method)..' "'..arg_url..query..'" '..table.concat(cmds, ' ')
end

function _M.request(method, url, args)

    method = string.upper(method or '')
    if not ({OPTIONS=1, HEAD=1, GET=1, PUT=1, POST=1, DELETE=1})[method] then
        return nil, 'bad method'
    end
    if not url then
        return nil, 'bad method'
    end
    args = args or {}
    local headers = {}
    local body = nil
    local query = ''
    for k, v in pairs(args) do
        if k == 'query' then
            query = '?'..ngx.encode_args(v);
        elseif k == 'body' then
            body = args.body
        elseif k == 'json' then
            body = cjson.encode(args.json)
            headers['Content-Type'] = 'application/json'
        elseif k == 'form_params' then
            body = ngx.encode_args(args.form_params)
            headers['Content-Type'] = 'application/x-www-form-urlencoded'
        elseif k == 'headers' then
            for k1, v1 in pairs(v) do
                headers[k1] = v1
            end
        end
    end

    local res, err
    local httpc = http.new()
    httpc:set_timeout(args.timeout or 200)

    --
    -- proxy需要lua-resty-http-0.12支持
    --
    if args.proxy then
        httpc:set_proxy_options{
            http_proxy = args.proxy
        }
    end

    local retry = args.retry or 10
    while retry > 0 do
        res, err = httpc:request_uri(url..query, {
            body = body,
            method = method,
            headers = headers
        })
        httpc:close()
        ngx.log(ngx.ERR, 'HTTPCERR_'..(err or 'OK')..'_RETRY_'..retry..' '..get_curl(method, url, args))
        retry = retry - 1
        if res or retry == 0 then
            break
        end
        ngx.sleep(args.retry_interval or 0.1)
    end
    if res and ({[301]=1,[302]=1,[200]=1,[204]=1,[206]=1})[res.status] then
        return res
    end
    error({
        err = err,
        body = res and res.body,
        status = res and res.status
    })

end

return _M

