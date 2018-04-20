local lup = require 'lib.lup'

--
-- in_array
--
assert(lup.in_array('ni', {'ni', 'hao', 'bu', 'kk'}))
assert(not lup.in_array('xni', {'ni', 'hao', 'bu', 'kk'}))

--
-- array_merge
--
local t1 = {1,2,3}
local t2 = {4,5,6}
lup.var_dump(lup.array_merge(t1, t2))

local t1 = {ni={1},2,3}
local t2 = {ni={4},5,6}
lup.var_dump(lup.array_merge(t1, t2))
lup.var_dump(lup.array_merge({ni={1},2,3}, {ni={4},5,6}))

--
-- parse_url
--
local url = 'http://baidu.com/path/to/file.ext'
lup.var_dump(lup.parse_url(url))

--
-- md5_file
--
assert('a7eef95d86c3649a192350845d8cb2ae' == lup.md5_file('/etc/issue'))


print('PASS')
