--
-- tjx@20200308
--

local sentry = require 'lib.sentry'
local config = require 'config.config'

local sen = sentry.new(config.sentry_dsn)

local function bad_func(n)
    return not_defined_func(n)
end

sen:call(bad_func, 'ni')
