use Test::Nginx::Socket::Lua 'no_plan';
use Cwd qw(cwd);

workers(1);

my $pwd = cwd();

our $HttpConfig = qq{
    lua_package_path "$pwd/lib/?.lua;;";
    lua_shared_dict test_shm 8m;
    lua_shared_dict my_worker_events 8m;
};

run_tests();

__DATA__



=== TEST 1: report_xrpc_status() failures active
--- http_config eval
qq{
    $::HttpConfig

    server {
        listen 2119;
        location = /status {
            return 200;
        }
    }
}
--- config
    location = /t {
        content_by_lua_block {
            local we = require "resty.worker.events"
            assert(we.configure{ shm = "my_worker_events", interval = 0.1 })
            local healthcheck = require("resty.healthcheck")
            local checker = healthcheck.new({
                name = "testing",
                shm_name = "test_shm",
                type = "xrpc",
                checks = {
                    active = {
                        healthy  = {
                            interval = 999, -- we don't want active checks
                            statuses = { 200 },
                            successes = 3,
                        },
                        unhealthy  = {
                            interval = 999, -- we don't want active checks
                            statuses = { 500 },
                            failures = 2,
                        },
                        handler = function(node, conf)end
                    },
                },
            })
            ngx.sleep(0.1) -- wait for initial timers to run once
            local ok, err = checker:add_target("127.0.0.1", 2119, nil, true)
            checker:report_xrpc_status("127.0.0.1", 2119, nil, 500, "active")
            checker:report_xrpc_status("127.0.0.1", 2119, nil, 500, "active")
            ngx.say(checker:get_target_status("127.0.0.1", 2119))  -- false
        }
    }
--- request
GET /t
--- response_body
false
--- error_log
checking healthy targets: nothing to do
checking unhealthy targets: nothing to do
unhealthy XRPC increment (1/2) for '(127.0.0.1:2119)'
unhealthy XRPC increment (2/2) for '(127.0.0.1:2119)'
event: target status '(127.0.0.1:2119)' from 'true' to 'false'




=== TEST 2: report_xrpc_status() successes active
--- http_config eval
qq{
    $::HttpConfig

    server {
        listen 2119;
        location = /status {
            return 200;
        }
    }
}
--- config
    location = /t {
        content_by_lua_block {
            local we = require "resty.worker.events"
            assert(we.configure{ shm = "my_worker_events", interval = 0.1 })
            local healthcheck = require("resty.healthcheck")
            local checker = healthcheck.new({
                name = "testing",
                shm_name = "test_shm",
                type = "xrpc",
                checks = {
                    active = {
                        healthy  = {
                            interval = 999, -- we don't want active checks
                            successes = 4,
                        },
                        unhealthy  = {
                            interval = 999, -- we don't want active checks
                            tcp_failures = 2,
                            failures = 3,

                        },
                        handler = function(node, conf)end
                    },
                },
            })
            ngx.sleep(0.1) -- wait for initial timers to run once
            local ok, err = checker:add_target("127.0.0.1", 2119, nil, false)
            checker:report_xrpc_status("127.0.0.1", 2119, nil, 200, "active")
            checker:report_xrpc_status("127.0.0.1", 2119, nil, 200, "active")
            checker:report_xrpc_status("127.0.0.1", 2119, nil, 200, "active")
            checker:report_xrpc_status("127.0.0.1", 2119, nil, 200, "active")
            ngx.say(checker:get_target_status("127.0.0.1", 2119))  -- true
        }
    }
--- request
GET /t
--- response_body
true
--- error_log
checking healthy targets: nothing to do
checking unhealthy targets: nothing to do
healthy SUCCESS increment (1/4) for '(127.0.0.1:2119)'
healthy SUCCESS increment (2/4) for '(127.0.0.1:2119)'
healthy SUCCESS increment (3/4) for '(127.0.0.1:2119)'
healthy SUCCESS increment (4/4) for '(127.0.0.1:2119)'
event: target status '(127.0.0.1:2119)' from 'false' to 'true'



=== TEST 3: report_xrpc_status() with success is a nop when active.healthy.successes == 0
--- http_config eval
qq{
    $::HttpConfig

    server {
        listen 2119;
        location = /status {
            return 200;
        }
    }
}
--- config
    location = /t {
        content_by_lua_block {
            local we = require "resty.worker.events"
            assert(we.configure{ shm = "my_worker_events", interval = 0.1 })
            local healthcheck = require("resty.healthcheck")
            local checker = healthcheck.new({
                name = "testing",
                shm_name = "test_shm",
                type = "xrpc",
                checks = {
                    active = {
                        healthy  = {
                            interval = 999, -- we don't want active checks
                            successes = 0,
                        },
                        unhealthy  = {
                            interval = 999, -- we don't want active checks
                            tcp_failures = 2,
                            failures = 3,
                        },
                        handler = function(node, conf)end
                    }
                },

            })
            ngx.sleep(0.1) -- wait for initial timers to run once
            local ok, err = checker:add_target("127.0.0.1", 2119, nil, false)
            checker:report_xrpc_status("127.0.0.1", 2119, nil, 200, "active")
            checker:report_xrpc_status("127.0.0.1", 2119, nil, 200, "active")
            checker:report_xrpc_status("127.0.0.1", 2119, nil, 200, "active")
            checker:report_xrpc_status("127.0.0.1", 2119, nil, 200, "active")
            ngx.say(checker:get_target_status("127.0.0.1", 2119, nil))  -- false
        }
    }
--- request
GET /t
--- response_body
false
--- error_log
checking healthy targets: nothing to do
checking unhealthy targets: nothing to do
--- no_error_log
healthy SUCCESS increment
event: target status '127.0.0.1 (127.0.0.1:2119)' from 'false' to 'true'



=== TEST 4: report_xrpc_status() with success is a nop when active.unhealthy.failures == 0
--- http_config eval
qq{
    $::HttpConfig

    server {
        listen 2119;
        location = /status {
            return 200;
        }
    }
}
--- config
    location = /t {
        content_by_lua_block {
            local we = require "resty.worker.events"
            assert(we.configure{ shm = "my_worker_events", interval = 0.1 })
            local healthcheck = require("resty.healthcheck")
            local checker = healthcheck.new({
                name = "testing",
                shm_name = "test_shm",
                type = "xrpc",
                checks = {
                    active = {
                        healthy  = {
                            interval = 999, -- we don't want active checks
                            successes = 4,
                        },
                        unhealthy  = {
                            interval = 999, -- we don't want active checks
                            tcp_failures = 2,
                            failures = 0,
                        },
                        handler = function(node, conf)end
                    },
                },
            })
            ngx.sleep(0.1) -- wait for initial timers to run once
            local ok, err = checker:add_target("127.0.0.1", 2119, nil, true)
            checker:report_xrpc_status("127.0.0.1", 2119, nil, 500, "active")
            checker:report_xrpc_status("127.0.0.1", 2119, nil, 500, "active")
            checker:report_xrpc_status("127.0.0.1", 2119, nil, 500, "active")
            checker:report_xrpc_status("127.0.0.1", 2119, nil, 500, "active")
            ngx.say(checker:get_target_status("127.0.0.1", 2119, nil))  -- true
        }
    }
--- request
GET /t
--- response_body
true
--- error_log
checking healthy targets: nothing to do
checking unhealthy targets: nothing to do
--- no_error_log
unhealthy XRPC increment
event: target status '(127.0.0.1:2119)' from 'true' to 'false'



=== TEST 5: report_xrpc_status() with success is a nop when active.unhealthy.failures == 3 and active.health.successes == 2
--- http_config eval
qq{
    $::HttpConfig

    server {
        listen 2119;
        location = /status {
            return 200;
        }
    }
}
--- config
    location = /t {
        content_by_lua_block {
            local we = require "resty.worker.events"
            assert(we.configure{ shm = "my_worker_events", interval = 0.1 })
            local healthcheck = require("resty.healthcheck")
            local checker = healthcheck.new({
                name = "testing",
                shm_name = "test_shm",
                type = "xrpc",
                checks = {
                    active = {
                        healthy  = {
                            interval = 999, -- we don't want active checks
                            successes = 2,
                        },
                        unhealthy  = {
                            interval = 999, -- we don't want active checks
                            failures = 3,
                        },
                        handler = function(node, conf)end
                    },
                },

            })
            ngx.sleep(0.1) -- wait for initial timers to run once
            local ok, err = checker:add_target("127.0.0.1", 2119, nil, true)
            checker:report_xrpc_status("127.0.0.1", 2119, nil, 200, "active")
            checker:report_xrpc_status("127.0.0.1", 2119, nil, 200, "active")
            ngx.say(checker:get_target_status("127.0.0.1", 2119, nil))  -- true
            checker:report_xrpc_status("127.0.0.1", 2119, nil, 500, "active")
            checker:report_xrpc_status("127.0.0.1", 2119, nil, 500, "active")
            ngx.say(checker:get_target_status("127.0.0.1", 2119, nil))  -- true
            checker:report_xrpc_status("127.0.0.1", 2119, nil, 500, "active")
            ngx.say(checker:get_target_status("127.0.0.1", 2119, nil))  -- false
            checker:report_xrpc_status("127.0.0.1", 2119, nil, 200, "active")
            checker:report_xrpc_status("127.0.0.1", 2119, nil, 200, "active")
            ngx.say(checker:get_target_status("127.0.0.1", 2119, nil))  -- true
        }
    }
--- request
GET /t
--- response_body
true
true
false
true
--- error_log
checking healthy targets: nothing to do
checking unhealthy targets: nothing to do
unhealthy XRPC increment (1/3) for '(127.0.0.1:2119)'
unhealthy XRPC increment (2/3) for '(127.0.0.1:2119)'
unhealthy XRPC increment (3/3) for '(127.0.0.1:2119)'
event: target status '(127.0.0.1:2119)' from 'true' to 'false'
healthy SUCCESS increment (1/2)
healthy SUCCESS increment (2/2)
event: target status '(127.0.0.1:2119)' from 'false' to 'true'



=== TEST 6: report_xrpc_status() special case when active.unhealthy.failures == 3 and active.health.successes == 2 and health.statuses [200] and unhealthy.statuses [501]
--- http_config eval
qq{
    $::HttpConfig

    server {
        listen 2119;
        location = /status {
            return 200;
        }
    }
}
--- config
    location = /t {
        content_by_lua_block {
            local we = require "resty.worker.events"
            assert(we.configure{ shm = "my_worker_events", interval = 0.1 })
            local healthcheck = require("resty.healthcheck")
            local checker = healthcheck.new({
                name = "testing",
                shm_name = "test_shm",
                type = "xrpc",
                checks = {
                    active = {
                        healthy  = {
                            interval = 999, -- we don't want active checks
                            statuses = { 200 },
                            successes = 1,
                        },
                        unhealthy  = {
                            interval = 999, -- we don't want active checks
                            statuses = { 501 },
                            failures = 2,
                        },
                        handler = function(node, conf)end
                    },
                },

            })
            ngx.sleep(0.1) -- wait for initial timers to run once
            local ok, err = checker:add_target("127.0.0.1", 2119, nil, true)
            checker:report_xrpc_status("127.0.0.1", 2119, nil, 200, "active")
            ngx.say(checker:get_target_status("127.0.0.1", 2119, nil))  -- true

            checker:report_xrpc_status("127.0.0.1", 2119, nil, 500, "active")
            checker:report_xrpc_status("127.0.0.1", 2119, nil, 500, "active")
            ngx.say(checker:get_target_status("127.0.0.1", 2119, nil))  -- true

            checker:report_xrpc_status("127.0.0.1", 2119, nil, 501, "active")
            checker:report_xrpc_status("127.0.0.1", 2119, nil, 501, "active")
            ngx.say(checker:get_target_status("127.0.0.1", 2119, nil))  -- false

            checker:report_xrpc_status("127.0.0.1", 2119, nil, 201, "active")
            ngx.say(checker:get_target_status("127.0.0.1", 2119, nil))  -- false

            checker:report_xrpc_status("127.0.0.1", 2119, nil, 200, "active")
            ngx.say(checker:get_target_status("127.0.0.1", 2119, nil))  -- true
        }
    }
--- request
GET /t
--- response_body
true
true
false
false
true
--- error_log
checking healthy targets: nothing to do
checking unhealthy targets: nothing to do
unhealthy XRPC increment (1/2) for '(127.0.0.1:2119)'
unhealthy XRPC increment (2/2) for '(127.0.0.1:2119)'
event: target status '(127.0.0.1:2119)' from 'true' to 'false'
healthy SUCCESS increment (1/1)
event: target status '(127.0.0.1:2119)' from 'false' to 'true'



=== TEST 7: start xrpc healthcheck with active.unhealthy.failures == 4 and active.health.successes == 2
--- ONLY
--- http_config eval
qq{
    $::HttpConfig

    lua_shared_dict request_counters 1m;

    server {
        listen 2119;

        location /status {
            content_by_lua_block {
                local uri = ngx.var.request_uri
                local counter = ngx.shared.request_counters

                counter:incr(uri, 1, 0)

                local current_count = counter:get(uri) or 0

                if current_count < 4 or current_count > 8 then
                    ngx.status = 200
                    ngx.say("OK")

                else
                    ngx.status = 500
                    ngx.say("ERROR")
                end
            }
        }
    }
}
--- config
    location = /t {
        content_by_lua_block {
            local we = require "resty.worker.events"
            assert(we.configure{ shm = "my_worker_events", interval = 0.1 })
            local healthcheck = require("resty.healthcheck")
            local checker = healthcheck.new({
                name = "testing",
                shm_name = "test_shm",
                type = "xrpc",
                checks = {
                    active = {
                        healthy  = {
                            interval = 0.5, -- we don't want active checks
                            successes = 2,
                        },
                        unhealthy  = {
                            interval = 0.5, -- we don't want active checks
                            failures = 2,
                        },
                        handler = function(node, conf)
                            local http = require('resty.http')
                            local httpc = http.new()
                            local res, err = httpc:request_uri("http://127.0.0.1:2119/status", {
                                method = "GET",
                                path = "/status",
                            })
                            if not res then
                                return false
                            end
                            return true, res.status
                        end
                    },
                },
            })
            ngx.sleep(0.1) -- wait for initial timers to run once
            checker:add_target("127.0.0.1", 2119, nil, true)
            ngx.sleep(0.5)
            ngx.say(checker:get_target_status("127.0.0.1", 2119, nil))  -- true
            ngx.sleep(2.0)
            ngx.say(checker:get_target_status("127.0.0.1", 2119, nil))  -- false
            ngx.sleep(4.0)
            ngx.say(checker:get_target_status("127.0.0.1", 2119, nil))  -- true
        }
    }
--- request
GET /t
--- timeout: 10
--- response_body
true
false
true
--- error_log
checking healthy targets: nothing to do
checking unhealthy targets: nothing to do
unhealthy XRPC increment (1/2) for '(127.0.0.1:2119)'
unhealthy XRPC increment (2/2) for '(127.0.0.1:2119)'
event: target status '(127.0.0.1:2119)' from 'true' to 'false'
healthy SUCCESS increment (1/2)
healthy SUCCESS increment (2/2)
event: target status '(127.0.0.1:2119)' from 'false' to 'true'
