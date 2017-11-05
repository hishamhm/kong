describe("Balancer", function()
  local singletons, balancer
  local UPSTREAMS_FIXTURES
  local TARGETS_FIXTURES
  --local uuid = require("kong.tools.utils").uuid

  
  setup(function()
    balancer = require "kong.core.balancer"
    singletons = require "kong.singletons"
    singletons.worker_events = require "resty.worker.events"
    singletons.dao = {}
    singletons.dao.upstreams = {
      find_all = function(self)
        return UPSTREAMS_FIXTURES
      end
    }
    
    singletons.worker_events.configure({
      shm = "kong_process_events", -- defined by "lua_shared_dict"
      timeout = 5,            -- life time of event data in shm
      interval = 1,           -- poll interval (seconds)
  
      wait_interval = 0.010,  -- wait before retry fetching event data
      wait_max = 0.5,         -- max wait time before discarding event
    })

    UPSTREAMS_FIXTURES = {
      {id = "a", name = "mashape", slots = 10, orderlist = {1,2,3,4,5,6,7,8,9,10} },
      {id = "b", name = "kong",    slots = 10, orderlist = {10,9,8,7,6,5,4,3,2,1} },
      {id = "c", name = "gelato",  slots = 20, orderlist = {1,2,3,4,5,6,7,8,9,10,11,12,13,14,15,16,17,18,19,20} },
      {id = "d", name = "galileo", slots = 20, orderlist = {20,19,18,17,16,15,14,13,12,11,10,9,8,7,6,5,4,3,2,1} },
      {id = "e", name = "getkong", slots = 10, orderlist = {1,2,3,4,5,6,7,8,9,10} },
    }
    
    TARGETS_FIXTURES = {
      -- 1st upstream; a
      {
        id = "a1",
        created_at = "003",
        upstream_id = "a",
        target = "mashape.com:80",
        weight = 10,
      },
      {
        id = "a2",
        created_at = "002",
        upstream_id = "a",
        target = "mashape.com:80",
        weight = 10,
      },
      {
        id = "a3",
        created_at = "001",
        upstream_id = "a",
        target = "mashape.com:80",
        weight = 10,
      },
      {
        id = "a4",
        created_at = "002",  -- same timestamp as "a2"
        upstream_id = "a",
        target = "mashape.com:80",
        weight = 10,
      },
      -- 2nd upstream; b
      {
        id = "b1",
        created_at = "003",
        upstream_id = "b",
        target = "mashape.com:80",
        weight = 10,
      },
      -- 3nd upstream; e
      {
        id = "e1",
        created_at = "001",
        upstream_id = "e",
        target = "127.0.0.1:2112",
        weight = 10,
      },
      {
        id = "e2",
        created_at = "002",
        upstream_id = "e",
        target = "127.0.0.1:2112",
        weight = 0,
      },
      {
        id = "e3",
        created_at = "003",
        upstream_id = "e",
        target = "127.0.0.1:2112",
        weight = 10,
      },
    }

    local function find_all_in_fixture_fn(fixture)
      return function(self, match_on)
        local ret = {}
        for _, rec in ipairs(fixture) do
          for key, val in pairs(match_on or {}) do
            if rec[key] ~= val then
              rec = nil
              break
            end
          end
          if rec then table.insert(ret, rec) end
        end
        return ret
      end
    end

    singletons.dao = {
      targets = {
        find_all = find_all_in_fixture_fn(TARGETS_FIXTURES)
      },
      upstreams = {
        find_all = find_all_in_fixture_fn(UPSTREAMS_FIXTURES)
      },
    }

    singletons.cache = {
      get = function(self, _, _, loader, arg)
        return loader(arg)
      end
    }


  end)

  describe("create_balancer()", function()
    local my_balancer
    setup(function()
      my_balancer = balancer._create_balancer(UPSTREAMS_FIXTURES[1])
    end)

    it("creates a balancer with a healthchecker", function()
      assert.truthy(my_balancer)
      assert.same({}, my_balancer.__targets_history)
      assert.truthy(my_balancer.__healthchecker)
      assert.truthy(my_balancer.__healthchecker_callback)
    end)
  end)

  describe("get_balancer()", function()
    local my_balancer
    setup(function()
      my_balancer = balancer._get_balancer("e")
    end)

    it("balancer and healthchecker are in sync", function()
      assert.truthy(my_balancer)
      assert.same({}, my_balancer.__targets_history)
      assert.truthy(my_balancer.__healthchecker)
      assert.truthy(my_balancer.__healthchecker_callback)
    end)
  end)

  describe("load_upstreams_dict_into_memory()", function()
    local upstreams_dict
    setup(function()
      upstreams_dict = balancer._load_upstreams_dict_into_memory()
    end)

    it("retrieves all upstreams as a dictionary", function()
      assert.is.table(upstreams_dict)
      for _, u in ipairs(UPSTREAMS_FIXTURES) do
        assert.equal(upstreams_dict[u.name], u.id)
        upstreams_dict[u.name] = nil -- remove each match
      end
      assert.is_nil(next(upstreams_dict)) -- should be empty now
    end)
  end)

  describe("load_targets_into_memory()", function()
    local targets
    local upstream
    setup(function()
      upstream = "a"
      targets = balancer._load_targets_into_memory(upstream)
    end)

    it("retrieves all targets per upstream, ordered", function()
      assert.equal(4, #targets)
      assert(targets[1].id == "a3")
      assert(targets[2].id == "a2")
      assert(targets[3].id == "a4")
      assert(targets[4].id == "a1")
    end)
  end)
end)
