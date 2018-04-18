return {
    redis_host = '127.0.0.1', 
    redis_port = 8888,
    store_level = 'L1',
    levels = {
        L3 = {
            disks ={
                -- '/data/acache/L3/disk00',
                -- '/data/acache/L3/disk01',
                -- '/data/acache/L3/disk02',
                -- '/data/acache/L3/disk03',
                -- '/data/acache/L3/disk04',
                -- '/data/acache/L3/disk05',
            },
            max_size = 10*1024*1024,
            -- max_size = 20 * 1024*1024*1024,
            min_uses = 2,
            faster = 'L2',
        },
        L2 = {
            disks ={
                -- '/data/acache/L2/disk01',
            },
            max_size = 1200*1024*1024,
            min_uses = 8,
            faster = 'L1',
            slower = 'L3',
        },
        L1 = {
            disks ={
                -- '/data/acache/L1/disk00',
            },
            max_size = 1*1024*1024,
            -- slower = 'L2',
        },
    }
}
