local redis = require 'lib.redis_retry'
local lup = require 'lib.lup'

redis.set('ni', 'hao')

assert('hao' == redis.get('ni'))

print('PASS')
