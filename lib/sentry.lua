--
-- tjx@20200308
--

local raven = require 'raven'
local sender_luasocket = require 'raven.senders.ngx'

local _M = {}

function _M.new(dsn)
    local self = {}
    local sender, err = sender_luasocket.new({
        dsn = dsn
    })
    local rvn = raven.new({
        sender = sender,
        tags = {
            foo = "bar"
        },
    })
    self.rvn = rvn
    return setmetatable(self, {__index = _M})
end

--
-- Send a message to sentry
--
function _M.message(self, content, tags)
    local id, err = self.rvn:captureMessage(content, {
        tags = tags
    })
    if not id then
        return nil, err
    end
    return true
end

--
-- Send an exception to sentry
--
function _M.exception(self, _type, value, module, tags)
    local exception = {{
        type = _type,
        value = value,
        module = module
    }}
    local id, err = self.rvn:captureException(exception, {
        tags = tags
    })
    if not id then
        return nil, err
    end
    return true
end

--
-- Catch an exception and send it to sentry
--
function _M.call(self, func, ...)
    --
    -- variable 'ok' should be false, and an exception will be sent to sentry
    --
    return self.rvn:call(func, ...)
end

return _M
