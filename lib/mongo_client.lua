--
-- tjx@20181018
--

local _M = {}

local moongoo = require 'resty.moongoo'
local config = require 'config.config'
local serpent = require 'serpent'


function _M.new(collection, mongo_config)
    local self = setmetatable({
    }, {
        __index = function(_, method)
            return setmetatable({}, {
                __call = function(_, self, ...)
                    local retry = 3
                    while retry > 0 do
                        local ok, ret = xpcall(function(...)
                            local mgobj = moongoo.new(mongo_config or config.mongo)
                            local coll = mgobj:db(mgobj.default_db):collection(collection)
                            local ret, err = coll[method](coll, ...)
                            mgobj:close()
                            return ret, err
                        end,
                        function(err)
                            return {
                                err = err,
                                traceback = debug.traceback()
                            }
                        end,
                        ...)
                        if ok then
                            return ret
                        end
                        ngx.log(ngx.ERR, 'moongoo_retry: '..serpent.block(ret))
                        if retry == 1 then
                            return nil, ret
                        end
                        ngx.sleep(0.1)
                        retry = retry - 1
                    end
                end
            })
        end
    })
    return self
end

return _M

-- coll.new(name, db)
-- coll._build_write_concern(self)
-- coll._get_last_error(self)
-- coll._check_last_error(self, ...)
-- coll.insert(self, docs)
-- coll.create(self, params)
-- coll.drop(self)
-- coll.drop_index(self, name)
-- coll.ensure_index(self, docs)
-- coll.full_name(self)
-- coll.options(self)
-- coll.remove(self, query, single)
-- coll.stats(self)
-- coll.index_information(self)
-- coll.rename(self, to_name, drop)
-- coll.update(self, query, update, flags)
-- coll.save(self, doc)
-- coll.map_reduce(self, map, reduce, flags)
-- coll.find(self, query, fields)
-- coll.find_one(self, query, fields)
-- coll.find_and_modify(self, query, opts)
-- coll.aggregate(self, pipeline, opts)
-- cur.new(collection, query, fields, explain, id)
-- cur.tailable(self, tailable)
-- cur.await(self, await)
-- cur.comment(self, comment)
-- cur.hint(self, hint)
-- cur.max_scan(self, max_scan)
-- cur.max_time_ms(self, max_time_ms)
-- cur.read_preference(self, read_preference)
-- cur.snapshot(self, snapshot)
-- cur.sort(self, sort)
-- cur.clone(self, explain)
-- cur.skip(self, skip)
-- cur.limit(self, limit)
-- cur._build_query(self)
-- cur.next(self)
-- cur.all(self)
-- cur.rewind(self)
-- cur.count(self)
-- cur.distinct(self, key)
-- cur.explain(self)
-- cur.add_batch(self, docs)
-- cur._finished(self)

