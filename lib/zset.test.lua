#!/usr/local/bin/env -S /usr/local/oresty/bin/resty -I ./lualib/
--
-- tjx@20200310
--

local lup = require 'lib.lup'
local zset = require 'lib.zset'

local zs = zset.new()

for i = 1, 10 do
    zs:add(1, 'key_'..math.random(0, 10))
end

local arr = zs:range(0, 10)

lup.var_dump(arr)
