# Oresty

基于openresty的web框架
- 支持异步任务，异步IO
- 比go性能好，比PHP入门简单

## Benchmark

go
php
oresty

## Usage

    bash check-env.sh

    ln -s config_dev config

    install oresty /etc/init.d/oresty

    /etc/init.d/oresty start

    ps aux|grep oresty

- swoole.lua

    用lua实现swoole，task-workers和request-workers隔离

- lup.lua

    用lua实现PHP的function

- client.lua

接口和PHP开源项目Guzzle完全一致
    http://docs.guzzlephp.org/
