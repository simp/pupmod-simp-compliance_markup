# vim: set expandtab ts=2 sw=2:
# 
# This is the shared codebase for the compliance_markup hiera
# backend. Each calling object (either the hiera backend class
# or the puppet lookup function) uses instance_eval to add these
# functions to the object. 
#
# Then the object can call enforcement like so:
# enforcement('key::name') do |key, default|
#   lookup(key, { "default_value" => default})
# end
#
# The block is used to abstract lookup() since Hiera v5 and Hiera v3 have
# different calling conventions
#
# This block will also return a KeyError if there is no key found, which must be
# trapped and converted into the correct response for the api. either throw :no_such_key
# or context.not_found()
#
# We also expect a small api in the object that includes these functions:
#
# debug(message)
# cached(key)
# cache(key, value)
# cache_has_key(key)
#
# which allow for debug logging, and caching, respectively. Hiera v5 provides this function
# natively, while Hiera v3 has to create it itself

def enforcement(key, &block)

  # Throw away keys we know we can't handle.
  # This also prevents recursion since these are the only keys internally we call.
  case key
  when "lookup_options"
    # XXX ToDo See note about compiling a lookup_options hash in the compiler
    throw :no_such_key
  when "compliance_map"
    throw :no_such_key
  when "compliance_markup::compliance_map"
    throw :no_such_key
  when "compliance_markup::compliance_map::percent_sign"
    throw :no_such_key
  when "compliance_markup::enforcement"
    throw :no_such_key
  when "compliance_markup::version"
    throw :no_such_key
  when "compliance_markup::percent_sign"
    throw :no_such_key
  else
    retval = :notfound
    if cache_has_key(:lock)
      lock = cached_value(:lock)
    else
      lock = false
    end
    if (lock == false)
      cache(:lock, true)
      begin
        profile_list = cached_lookup "compliance_markup::enforcement", [], &block
        unless (profile_list == [])
          debug("compliance_markup::enforcement set to #{profile_list}, attempting to enforce")
          version = cached_lookup "compliance_markup::version", "1.0.0", &block
          case version
          when /1.*/
            v1_compliance_map = {}

            if (cache_has_key(:v1_compliance_map))
              v1_compliance_map = cached_value(:v1_compliance_map)
            else
              debug("loading compliance_map data from compliance_markup::compliance_map")
              module_scope_compliance_map = cached_lookup "compliance_markup::compliance_map", {}, &block
              top_scope_compliance_map = cached_lookup "compliance_map", {}, &block
              v1_compliance_map.merge!(module_scope_compliance_map)
              v1_compliance_map.merge!(top_scope_compliance_map)
              cache(:v1_compliance_map, v1_compliance_map)
              # XXX ToDo: Add a dynamic loader for compliance data, so that modules can embed
              # their own compliance map information. Dylan has a way to do this in testing
              # in Abacus
            end


            profile = profile_list.hash.to_s
            v1_compile(profile, profile_list, v1_compliance_map)
            if (v1_compliance_map.key?(profile))
              # Handle a knockout prefix
              unless (v1_compliance_map[profile].key?("--" + key))
                if (v1_compliance_map[profile].key?(key))
                  retval = v1_compliance_map[profile][key]
                end
              end
            end
          end
        end
      ensure
        cache(:lock, false)
      end
    end
    if (retval == :notfound)
      throw :no_such_key
    end
  end
  return retval
end

# Pre-compile the values for each profile list array.
# We use hash.to_s, then create a hash named that in v1_compliance_map,
# that is a raw key => value mapping. This simplifies our code as we can assume
# that if the key exists, then the value is what we use. We also don't have to worry
# about exponential time issues since this is linearlly done once, not every time for
# every key.

def v1_compile(profile, profile_list, v1_compliance_map)
  unless (v1_compliance_map.key?(profile))
    compile_start_time = Time.now
    debug("compliance map for #{profile_list} not found, starting compiler")
    table = {}
    # Set the keys in reverse order. This means that [ 'disa', 'nist'] would prioritize
    # disa values over nist. Only bother to store the highest priority value
    profile_list.reverse.each do |profile_map|
      if (profile_map != /^v[0-9]+/)
        if (v1_compliance_map.key?(profile_map))
          v1_compliance_map[profile_map].each do |key, entry|
            if (entry.key?("value"))
              # XXX ToDo: Generate a lookup_options hash, set to 'first', if the user specifies some
              # option that toggles it on. This would allow un-overridable enforcement at the hiera
              # layer (though it can still be overridden by resource-style class definitions
              table[key] = entry["value"]
            end
          end
        end
      end
    end
    v1_compliance_map[profile] = table
    compile_end_time = Time.now
    debug("compiled compliance_map containing #{table.size} keys in #{compile_end_time - compile_start_time} seconds")
    # This is necessary for hiera v5 since the cache
    # is immutable.
    cache(:v1_compliance_map, v1_compliance_map)
  end
end

# These cache functions are assumed to be created by the wrapper
# object, either the v3 backend or v5 backend.
def cached_lookup(key, default, &block)
  if (cache_has_key(key))
    retval = cached_value(key)
  else
    retval = yield key, default
    cache(key, retval)
  end
  retval
end

