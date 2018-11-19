local typedefs = require "kong.db.schema.typedefs"


return {
  name         = "routes",
  primary_key  = { "id" },
  endpoint_key = "name",
  subschema_key = "protocols",

  fields = {
    { id             = typedefs.uuid, },
    { created_at     = typedefs.auto_timestamp_s },
    { updated_at     = typedefs.auto_timestamp_s },
    { name           = typedefs.name },
    { protocols      = { type     = "set",
                         len_min  = 1,
                         required = true,
                         elements = typedefs.protocol,
                         default  = { "http", "https" },
                       }, },
    { methods = { type = "set", elements = { type = "string" }, abstract = true } },
    { hosts = { type = "array", elements = { type = "string" }, abstract = true } },
    { paths = { type = "array", elements = { type = "string" }, abstract = true } },
    { snis = { type = "set", elements = { type = "string" }, abstract = true } },
    { sources = { type = "set", elements = { type = "record", fields = {} }, abstract = true } },
    { destinations = { type = "set", elements = { type = "record", fields = {} }, abstract = true } },

    { regex_priority = { type = "integer", default = 0 }, },
    { strip_path     = { type = "boolean", default = true }, },
    { preserve_host  = { type = "boolean", default = false }, },
    { service        = { type = "foreign", reference = "services", required = true }, },
  },
}
