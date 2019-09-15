--
-- User: tangjunxing
-- Date : 2017/08/31
--

local lup = require 'lib.lup'
local serpent = require 'serpent'
local template = require 'resty.template'
local lup = require 'lib.lup'
local lfs = require 'lfs'

local _M = {
    version = 190924
}

local inited = false
local loaded = {}
function _M.new(dir, debug)
    if not inited then
        ngx.log(ngx.ERR, 'DIR: ', dir)
        for file in lfs.dir(dir) do
            local pathinfo = lup.pathinfo(file)
            if 'lua' == pathinfo.extension then
                local filename = pathinfo.filename
                ngx.log(ngx.ERR, 'filename: ', filename)
                loaded[filename] = require('ctrl.'..filename)
            end
        end
        inited = true
    end
    local self = {}
    return setmetatable({debug = debug}, {__index = _M})
end

function _M.dispatch(self, route, method, params)

    --
    -- 调用方法，并且渲染输出
    --
    local ok, ret = xpcall(function()

        local ctrl = loaded[route or '']
        if not ctrl then
            ngx.status = 404
            error('CTRL_NOT_FOUND')
        elseif not ctrl[method] then
            ngx.status = 404
            error('METHOD_NOT_FOUND')
        end

        lup.var_dump({
            route = route,
            method = method,
            params = params,
        })

        local ret, template_path = ctrl[method](params)
        if template_path then
            template.render(template_path, ret)
        elseif type(ret) == 'table' then
            ngx.header.content_type = 'application/json'
            ngx.say(lup.json_encode(ret))
        elseif type(ret) == 'string' then
            ngx.header.content_type = 'text/plain'
            ngx.print(ret)
        elseif ret == nil then
        else
            error('UNKNOWN_RET_CONTENT_TYPE')
        end
    end,
    function(err)
        return {
            err = err,
            traceback = debug.traceback()
        }
    end)

    --
    -- 异常处理
    --
    if not ok then
        if ngx.status == 0 then
            ngx.status = 500
        end
        ret = ret or {}
        ngx.log(ngx.ERR, serpent.line({
            status = ngx.status,
            err = ret.err,
            traceback = ret.traceback,
        }, {comment = false}))
        ngx.say(lup.json_encode({
            params = params,
            r = r,
            title = 'exception',
            http_code = ngx.status,
            reqid = ngx.var.http_x_upos_reqid,
            error = ret.err,
            traceback = self.debug and lup.explode('\n\t', ret.traceback or '') or nil,
        }))
    end

end

return _M
