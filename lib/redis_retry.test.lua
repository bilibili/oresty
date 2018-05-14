local serpent = require 'serpent'
local redis_retry = require 'lib.redis_retry'

local red = redis_retry.new('127.0.0.1', 6379, 3)

print(red:set('ni', 'hao'))
print(red:get('ni'))
