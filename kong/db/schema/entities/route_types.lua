local typedefs = require "kong.db.schema.typedefs"


local route_types = {}


local function validate_host_with_wildcards(host)
  local no_wildcards = string.gsub(host, "%*", "abc")
  return typedefs.host.custom_validator(no_wildcards)
end


local function validate_path_with_regexes(path)

  local ok, err, err_code = typedefs.path.custom_validator(path)

  if ok or err_code ~= "rfc3986" then
    return ok, err, err_code
  end

  -- URI contains characters outside of the reserved list of RFC 3986:
  -- the value will be interpreted as a regex by the router; but is it a
  -- valid one? Let's dry-run it with the same options as our router.
  local _, _, err = ngx.re.find("", path, "aj")
  if err then
    return nil,
           string.format("invalid regex: '%s' (PCRE returned: %s)",
                         path, err)
  end

  return true
end


local application_layer_route = {
  fields = {
    { protocols = {
      type = "set",
      len_min  = 1,
      required = true,
      elements = {
        type = "string",
        one_of = { "http", "https" }
      },
    } },
    { methods = {
      type = "set",
      elements = typedefs.http_method,
    } },
    { hosts = {
      type = "array",
      elements = {
        type = "string",
        match_all = {
          {
            pattern = "^[^*]*%*?[^*]*$",
            err = "invalid wildcard: must have at most one wildcard",
          },
        },
        match_any = {
          patterns = { "^%*%.", "%.%*$", "^[^*]*$" },
          err = "invalid wildcard: must be placed at leftmost or rightmost label",
        },
        custom_validator = validate_host_with_wildcards,
      }
    } },
    { paths = {
      type = "array",
      elements = typedefs.path {
        custom_validator = validate_path_with_regexes,
        match_none = {
          { pattern = "//",
            err = "must not have empty segments"
          },
        },
      }
    } },
    { snis = typedefs.empty_set {
      err = "cannot set 'snis' when 'protocols' is 'http' or 'https'",
    } },
    { sources = typedefs.empty_set {
      err = "cannot set 'sources' when 'protocols' is 'http' or 'https'",
    } },
    { destinations = typedefs.empty_set {
      err = "cannot set 'destinations' when 'protocols' is 'http' or 'https'",
    } },
  },
  entity_checks = {
    { at_least_one_of = { "methods", "hosts", "paths" } }
  }
}


local transport_layer_route = {
  fields = {
    { protocols = {
      type = "set",
      len_min  = 1,
      required = true,
      elements = {
        type = "string",
        one_of = { "tcp", "tls" }
      },
    } },
    { hosts = typedefs.empty_array {
      err = "cannot set 'hosts' when 'protocols' is 'tcp' or 'tls'",
    } },
    { methods = typedefs.empty_set {
      err = "cannot set 'methods' when 'protocols' is 'tcp' or 'tls'",
    } },
    { paths = typedefs.empty_array {
      err = "cannot set 'paths' when 'protocols' is 'tcp' or 'tls'",
    } },
    { snis = {
      type = "set",
      elements = typedefs.sni
    } },
    { sources = {
      type = "set",
      elements = {
        type = "record",
        fields = {
          { ip = typedefs.cidr },
          { port = typedefs.port },
        },
        entity_checks = {
          { at_least_one_of = { "ip", "port" } }
        },
      },
    } },
    { destinations = {
      type = "set",
      elements = {
        type = "record",
        fields = {
          { ip = typedefs.cidr },
          { port = typedefs.port },
        },
        entity_checks = {
          { at_least_one_of = { "ip", "port" } }
        },
      },
    }, },
  },
  entity_checks = {
    { at_least_one_of = { "snis", "sources", "destinations" } }
  }
}


function route_types.add_route_subschemas(routes_schema)
  routes_schema:new_subschema("http",  application_layer_route)
  routes_schema:new_subschema("https", application_layer_route)
  routes_schema:new_subschema("tcp", transport_layer_route)
  routes_schema:new_subschema("tls", transport_layer_route)
end


return route_types
