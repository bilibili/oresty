
local _M = {}

local mongol = require 'resty.mongol'
local config = require 'config.config'
local serpent = require 'serpent'

local function connect(collection)
    local conn = mongol:new()
    for _, host in ipairs(config.mongo.hosts) do
        local ok, err = conn:connect(host.ip, host.port)
        if ok then
            conn:set_timeout(2000)
        else
            ngx.log(ngx.ERR, host.ip..':'..host.port..' '..err)
        end
    end

    local db = conn:new_db_handle(config.mongo.database)
    local coll, err = db:get_col(collection)
    assert(not err, err)
    return coll
end

function _M.new(collection)
    local instance = setmetatable({}, {
        __index = function(_, method)
            return setmetatable({}, {
                __call = function(_, ...)
                    local retry = 3
                    while retry > 0 do
                        local ok, ret = xpcall(function(...)
                            local coll = connect(collection)
                            local ret, err = coll[method](coll, ...)
                            if err then
                                error(err)
                            end
                            return ret
                        end,
                        function(err)
                            ngx.log(ngx.ERR, serpent.block({err=err,traceback=debug.traceback()}))
                            return {
                                err = err,
                                traceback = debug.traceback()
                            }
                        end,
                        ...)
                        if ok then
                            return ret
                        elseif retry == 1 then
                            error(ret)
                        end
                        ngx.sleep(0.1)
                        retry = retry - 1
                    end
                end
            })
        end
    })
    return instance
end

-- local mongo = _M.new('history_du')
-- ngx.say(serpent.block(mongo.find_one({}), {comment=false}))

return _M

