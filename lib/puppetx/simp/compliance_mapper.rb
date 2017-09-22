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
    if cache_has_key("lock")
      lock = cached_value("lock")
    else
      lock = false
    end
    if (lock == false)
      cache("lock", true)
      begin
        profile_list = cached_lookup "compliance_markup::enforcement", [], &block
        unless (profile_list == [])
          debug("compliance_markup::enforcement set to #{profile_list}, attempting to enforce")
          profile = profile_list.hash.to_s
          if (cache_has_key("compliance_map_#{profile}"))
            profile_map = cached_value("compliance_map_#{profile}")
          else
            debug("compliance map for #{profile_list} not found, starting compiler")
            compile_start_time = Time.now
            profile_compiler = compiler_class.new(self)
            profile_compiler.load(&block)
            profile_map = profile_compiler.list_puppet_params(profile_list).cook do |item|
              item["value"]
            end
            cache("compliance_map_#{profile}", profile_map)
            compile_end_time = Time.now
            debug("compiled compliance_map containing #{profile_map.size} keys in #{compile_end_time - compile_start_time} seconds")
          end
          # Handle a knockout prefix
          unless (profile_map.key?("--" + key))
            if (profile_map.key?(key))
              retval = profile_map[key]
            end
          end

          # XXX ToDo: Generate a lookup_options hash, set to 'first', if the user specifies some
          # option that toggles it on. This would allow un-overridable enforcement at the hiera
          # layer (though it can still be overridden by resource-style class definitions)
        end
      rescue Exception => ex
      ensure
        cache("lock", false)
      end
    end
    if (retval == :notfound)
      throw :no_such_key
    end
  end
  return retval
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

def compiler_class()
  Class.new do
    def initialize(object)
      @callback = object
    end
    def callback
      @callback
    end

    def load(&block)
      @compliance_data = []
      module_scope_compliance_map = callback.cached_lookup "compliance_markup::compliance_map", {}, &block
      top_scope_compliance_map = callback.cached_lookup "compliance_map", {}, &block
      @compliance_data << (module_scope_compliance_map)
      @compliance_data << (top_scope_compliance_map)
      location = __FILE__
      moduleroot = File.dirname(File.dirname(File.dirname(File.dirname(File.dirname(location)))))

      # Dynamically load v1 compliance map data from modules.
      # Create a set of yaml files (all containing compliance info) in your modules, in
      # lib/puppetx/compliance/module_name/v1/whatever.yaml
      # Note: do not attempt to merge or rely on merge behavior for v1
      Dir.glob(moduleroot + "/*/lib/puppetx/compliance/*/v1/*.yaml") do |filename|
        begin
          @compliance_data << YAML.load(File.read(filename))
        rescue
        end
      end
    end
    def control_list()
      Class.new do
        include Enumerable
        def initialize(hash)
          @hash = hash
        end
        def [](key)
          @hash[key]
        end
        def each(&block)
          @hash.each(&block)
        end
        def cook(&block)
          nhash = {}
          @hash.each do |key, value|
            nvalue = yield value
            nhash[key] = nvalue
          end
          nhash
        end
      end
    end
    def list_puppet_params(profile_list)

      table = {}
      # Set the keys in reverse order. This means that [ 'disa', 'nist'] would prioritize
      # disa values over nist. Only bother to store the highest priority value
      profile_list.reverse.each do |profile_map|
        if (profile_map != /^v[0-9]+/)
          @compliance_data.each do |map|
            result = v1_parser(profile_map,map)
            table.merge!(result)
          end
        end
      end
      control_list.new(table)
    end
    def v1_parser(profile, hashmap)
      table = {}
      if (hashmap.key?(profile))
        hashmap[profile].each do |key, entry|
          if (entry.key?("value"))
            table[key] = entry
          end
        end
      end
      table
    end
  end
end



# vim: set expandtab ts=2 sw=2:
