local helpers = require "spec.helpers"
local pl_utils = require "pl.utils"


local dao = helpers.dao -- postgreSQL DAO (faster to test this command)


describe("kong migrations", function()

  local db_update_propagation = helpers.test_conf.database == "cassandra" and 3 or 0

  describe("reset", function()
    before_each(function()
      assert(dao:run_migrations())
    end)

    teardown(function()
      dao:drop_schema()
    end)

    it("runs interactively by default", function()
      local answers = {
        "y",
        "Y",
        "yes",
        "YES",
      }

      for _, answer in ipairs(answers) do
        local cmd = string.format(helpers.unindent [[
          echo %s | KONG_DB_UPDATE_PROPAGATION=%d %s migrations reset -c %s
        ]], answer, db_update_propagation, helpers.bin_path, helpers.test_conf_path)

        local ok, _, stdout, stderr = pl_utils.executeex(cmd)
        assert.is_true(ok)
        assert.equal("", stderr)
        assert.matches("Are you sure? This operation is irreversible. [Y/n]",
                       stdout, nil, true)
        assert.matches("Schema successfully reset", stdout, nil, true)
        assert(dao:run_migrations())
      end
    end)

    it("cancels when ran interactively", function()
      local answers = {
        "n",
        "N",
        "no",
        "NO",
      }

      for _, answer in ipairs(answers) do
        local cmd = string.format(helpers.unindent [[
          echo %s | KONG_DB_UPDATE_PROPAGATION=%d %s migrations reset -c %s
        ]], answer, db_update_propagation, helpers.bin_path, helpers.test_conf_path)
        local ok, _, stdout, stderr = pl_utils.executeex(cmd)
        assert.is_true(ok)
        assert.equal("", stderr)
        assert.matches("Are you sure? This operation is irreversible. [Y/n]",
                       stdout, nil, true)
        assert.matches("Canceled", stdout, nil, true)
      end
    end)

    it("runs non-interactively with --yes", function()
      local ok, stderr, stdout = helpers.kong_exec("migrations reset --yes -c " ..
                                                   helpers.test_conf_path, {
        db_update_propagation = db_update_propagation,
      })
      assert.is_true(ok)
      assert.is_equal("", stderr)
      assert.not_matches("Are you sure? This operation is irreversible. [Y/n]",
                         stdout, nil, true)
      assert.matches("Schema successfully reset", stdout, nil, true)
    end)

    it("runs non-interactively with -y", function()
      local ok, stderr, stdout = helpers.kong_exec("migrations reset -y -c " ..
                                                   helpers.test_conf_path, {
        db_update_propagation = db_update_propagation,
      })
      assert.is_true(ok)
      assert.is_equal("", stderr)
      assert.not_matches("Are you sure? This operation is irreversible. [Y/n]",
                         stdout, nil, true)
      assert.matches("Schema successfully reset", stdout, nil, true)
    end)
  end)
end)
