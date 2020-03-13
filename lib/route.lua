--
-- tjx@20200313
--
-- Usage:
-- 
--     local rt = route.new()
--     rt:dispatch(nil, 'home', 'get', {
--         a = b,
--         c = d
--     })
--
--     or self defined route dirs
--
--     local rt = route.new({'./ctrl/', 'ctrl1'})
--     rt:dispatch('ctrl', 'home', 'get', {
--         a = b,
--         c = d
--     })
--     rt:dispatch('ctrl1', 'home1', 'get', {
--         a = b,
--         c = d
--     })
--

local lup = require 'lib.lup'
local serpent = require 'serpent'
local template = require 'resty.template'
local lfs = require 'lfs'

local _M = {
    version = 20200313
}

local inited = false
local loaded = {}
function _M.new(dirs)
    local dirs = dirs or {'./ctrl/'}
    for _, dir in ipairs(dirs) do
        local dirname = lup.basename(lup.trim(dir, '/'))
        if not inited then
            for file in lfs.dir(dir) do
                local pathinfo = lup.pathinfo(file)
                if 'lua' == pathinfo.extension then
                    local filename = pathinfo.filename
                    loaded[dirname..'/'..filename] = require(dir..'/'..filename)
                    ngx.log(ngx.ERR, 
                    dirname..'/'..filename..' => '..dir..'/'..filename
                    )
                end
            end
        end
    end
    inited = true
    return setmetatable({}, {__index = _M})
end

function _M.dispatch(self, dirname, route, method, params)

    dirname = dirname or 'ctrl'
    assert(route, 'ROUTE_NIL')

    --
    -- 调用方法，并且渲染输出
    --
    local ok, ret = xpcall(function()
        assert(route, 'ROUTE_NIL')
        local ctrl = loaded[dirname..'/'..route]
        if not ctrl then
            ngx.status = 404
            error('CTRL_NOT_FOUND_'..dirname..'/'..route)
        elseif not ctrl[method] then
            ngx.status = 404
            error('METHOD_NOT_FOUND')
        end
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
            error('ROUTE_UNKNOWN_RET_TYPE')
        end
    end,
    function(err)
        ngx.log(ngx.ERR, serpent.line({
            err = err,
            traceback = debug.traceback(),
        }, {comment = false}))
        return err
    end)

    --
    -- 异常处理
    --
    if not ok then
        if ngx.status == 0 then
            ngx.status = 500
        end
        ngx.say(lup.json_encode({
            params = params,
            http_code = ngx.status,
            reqid = ngx.var.http_x_upos_reqid,
            err = ret,
        }))
    end

end

return _M
