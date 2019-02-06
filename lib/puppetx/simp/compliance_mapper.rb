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


def enforcement(key, options = {"mode" => "value"}, &block)
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
    if lock == false

      debug_output = {}
      cache("lock", true)

      begin
        profile_list = cached_lookup "compliance_markup::enforcement", [], &block
        unless (profile_list == [])
          debug("debug: compliance_markup::enforcement set to #{profile_list}, attempting to enforce")

          profile = profile_list.hash.to_s

          if cache_has_key("compliance_map_#{profile}")
            profile_map = cached_value("compliance_map_#{profile}")
          else
            debug("debug: compliance map for #{profile_list} not found, starting compiler")

            compile_start_time = Time.now
            profile_compiler = compiler_class.new(self)

            profile_compiler.load(&block)

            profile_map = profile_compiler.list_puppet_params(profile_list).cook do |item|
              debug_output[item["parameter"]] = item["telemetry"]
              item[options["mode"]]
            end

            cache("debug_output_#{profile}", debug_output)

            compile_end_time = Time.now

            profile_map["compliance_markup::debug::hiera_backend_compile_time"] = (compile_end_time - compile_start_time)
            cache("compliance_map_#{profile}", profile_map)
            debug("debug: compiled compliance_map containing #{profile_map.size} keys in #{compile_end_time - compile_start_time} seconds")
          end
          if key == "compliance_markup::debug::dump"
            retval = profile_map
          else
            # Handle a knockout prefix
            unless profile_map.key?("--" + key)
              if profile_map.key?(key)
                debug("debug: v2 details for #{key}")

                retval = profile_map[key]
                files = {}

                debug_output[key].each do |telemetryinfo|
                  unless files.key?(telemetryinfo["filename"])
                    files[telemetryinfo["filename"]] = []
                  end
                  files[telemetryinfo["filename"]] << telemetryinfo
                end

                files.each do |k, v|
                  debug("     #{k}:")

                  v.each do |value2|
                    debug("             #{value2['id']}")
                    debug("                        #{value2['value']['settings']['value']}")
                  end
                end
              end
            end
          end

          # XXX ToDo: Generate a lookup_options hash, set to 'first', if the user specifies some
          # option that toggles it on. This would allow un-overridable enforcement at the hiera
          # layer (though it can still be overridden by resource-style class definitions)
        end
      rescue Exception => e
        if $debugmode
          binding.pry
        end
      ensure
        cache("lock", false)
      end
    end
    if retval == :notfound
      throw :no_such_key
    end
  end
  return retval
end


# These cache functions are assumed to be created by the wrapper
# object, either the v3 backend or v5 backend.
def cached_lookup(key, default, &block)
  if cache_has_key(key)
    retval = cached_value(key)
  else
    retval = yield key, default
    cache(key, retval)
  end
  retval
end

def compiler_class()
  Class.new do
    attr_reader :compliance_data
    attr_reader :callback
    attr_accessor :v2

    def initialize(object)
      require 'semantic_puppet'

      @callback = object
    end

    def load(&block)
      @callback.debug("callback = #{callback.codebase}")

      @compliance_data = {}

      module_scope_compliance_map = callback.cached_lookup "compliance_markup::compliance_map", {}, &block
      top_scope_compliance_map = callback.cached_lookup "compliance_map", {}, &block

      @compliance_data["puppet://compliance_markup::compliance_map"] = (module_scope_compliance_map)
      @compliance_data["puppet://compliance_map"] = (top_scope_compliance_map)

      moduleroot = File.expand_path('../../../../../', __FILE__)
      rootpaths = {}

      # Dynamically load v1 compliance map data from modules.
      # Create a set of yaml files (all containing compliance info) in your modules, in
      # lib/puppetx/compliance/module_name/v1/whatever.yaml
      # Note: do not attempt to merge or rely on merge behavior for v1
      begin
        environmentroot = "#{Puppet[:environmentpath]}/#{callback.environment}"
        env = Puppet::Settings::EnvironmentConf.load_from(environmentroot, ["/test"])
        rmodules = env.modulepath.split(":")
        rootpaths[environmentroot] = true
      rescue StandardError => ex
        callback.debug(ex)

        rmodules = []
      end
      modpaths = rmodules + [moduleroot]
      modpaths2 = []

      modpaths.each do |modpath|
        if modpath == "$basemodulepath"
          modpaths2 = modpaths2 + Puppet[:basemodulepath].split(":")
        else
          modpaths2 = modpaths2 + [modpath]
        end
      end
      modpaths2.each do |modpath|
        begin
          Dir.glob("#{modpath}/*") do |modulename|
            begin
              rootpaths[modulename] = true
            rescue
            end
          end
        rescue
        end
      end
      rootpaths.each do |path, dontcare|

        load_paths = [
            # This path is deprecated and only exists
            # to provide backwards compatibility
            # with SIMP EE 6.1 and 6.2
            "/lib/puppetx/compliance",
            "/SIMP/compliance_profiles",
            "/simp/compliance_profiles",
        ]

        ['yaml', 'json'].each do |type|
          load_paths.each do |pathspec|

            interp_pathspecs = [
                path + "#{pathspec}/*.#{type}",
                path + "#{pathspec}/**/*.#{type}",
            ]

            interp_pathspecs.each do |interp_pathspec|
              Dir.glob(interp_pathspec) do |filename|
                filedata = @callback.cached_file_data(filename)
                begin
                  case type
                  when 'yaml'
                    @compliance_data[filename] = YAML.load(filedata)
                  when 'json'
                    @compliance_data[filename] = JSON.parse(filedata)
                  end
                rescue
                end
              end
            end
          end
        end
      end

      @v2 = v2_compiler.new(callback)

      @compliance_data.each do |filename, map|
        if map.key?("version")
          version = SemanticPuppet::Version.parse(map["version"])

          if version.major == 2
            v2.import(filename, map)
          end
        end
      end
    end

    def ce
      v2.ce
    end

    def control
      v2.control
    end

    def check
      v2.check
    end

    def profile
      v2.profile
    end

    def standard
      v2.standard
    end

    def oval_id(id, options = {})
      result = v2.oval_id(id, options)
      if result["checks"] == {} and result["ces"] == {}
        result = {
            "checks" => {},
            "ces" => {},
        }
        @compliance_data.each do |filename, map|

          # Assume version 1 if no version is specified.
          # Due to old archaic code
          version = SemanticPuppet::Version.parse('1.0.0')

          if map.key?("version")
            version = SemanticPuppet::Version.parse(map["version"])
          end

          if version.major == 1
            map.each do |nkey, nvalue|
              unless nkey == "version"
                nvalue.each do |key, value|
                  if value.key?("oval-ids")
                    if value["oval-ids"].include?(id)
                      data = {
                          "type" => "puppet-class-parameter",
                          "settings" => {
                              "parameter" => key,
                              "value" => value["value"]
                          },
                          "identifiers" => value["identifiers"]
                      }
                      result["checks"]["oval:compliance_markup_v1:#{nkey}:#{key}"] = data
                    end
                  end
                end
              end
            end
          end
        end
      end
      result
    end

    def template_info(standard_name)
      if (standard.key?(standard_name))
        standard[standard_name]["options"]
      else
        {}
      end
    end

    def template(standard_name, options)
      # Store metadata at profile creation time.
      output = {
          'metadata' => {
              'standard' => {
                  "name" => standard_name,
                  "options" => options,
              }
          },
          'controls' => {}
      }
      # Loop through each control and check to see if is a part of the standard we use
      # as a template.
      control.each do |name, value|
        next unless (value.key?('standard'))
        next unless (value['standard'].key?('name'))
        next unless (value['standard']['name'] == standard_name)
        next unless (value['standard'].key?('template'))
        value['standard']['template'].each do |var_name, values|
          # for NIST var_name is either confidentiality, integrity, or
          # availability.
          # check if these are defined in the option, and then if this control is part
          # of this baseline.
          if (options.key?(var_name))
            if (values.include?(options[var_name]))
              output['controls'][name] = true
            end
          end
        end
      end
      output
    end

    def v2_compiler()
      Class.new do
        def initialize(callback)
          @data = {}
          @data_locations = {
              "ce" => {},
              "profiles" => {},
              "controls" => {},
              "checks" => {},
          }
          @callback = callback
        end

        def callback
          @callback
        end

        def ce
          @data[:ce] ? @data[:ce] : {}
        end

        def control
          @data[:controls] ? @data[:control]  : {}
        end

        def check
          @data[:checks] ? @data[:checks] : {}
        end

        def profile
          @data[:profiles] ? @data[:profiles] : {}
        end

        def control_family
          @data[:control_families] ? @data[:control_families] : {}
        end

        def standard
          @data[:standard] ? @data[:standard] : {}
        end

        def oval_id(id, options = {})
          result = {
              "checks" => {},
              "ces" => {},
          }
          # only return the first result atm
          check.each do |name, checkdata|
            if (checkdata.key?("oval-ids"))
              if (checkdata["oval-ids"].include?(id))
                result["checks"][name] = checkdata
              end
            end
            if checkdata.key?("ces")
              checkdata["ces"].each do |cename|
                if (ce.key?(cename))
                  if ce[cename].key?("oval-ids")
                    if ce[cename]["oval-ids"].include?(id)
	              result['ces'][cename] = ce[cename]
                      result["checks"][name] = checkdata
                    end
                  end
                end
              end
            end
          end
          result
        end

        def import(filename, data)
          settings = [
              'profiles',
              'controls',
              'checks',
              'ce',
              'control_families',
              'standards',
          ]
          data.each do |key, value|
            if settings.include?(key)
              keysym = key.to_sym
              @data[keysym] = {} unless @data.key?(keysym)
              value.each do |name, map|
                unless (@data[keysym].key?(name))
                  @data[keysym][name] = {}
                end
                map.each do |key2, value|
                  @data[keysym][name][key2] = value
                end
                @data[keysym][name]["telemetry"] = [{"filename" => filename, "path" => "#{key}/#{name}", "id" => "#{name}", "value" => Marshal.load(Marshal.dump(map))}]
              end
            end
          end
        end

        def list_puppet_params(profile_list)
          retval = {}
          profile_list.reverse.each do |nprofile|
            if (profile.key?(nprofile))
              info = profile[nprofile]
              check.each do |ncheck, spec|
                specification = Marshal.load(Marshal.dump(spec))
                continue = true

                if (specification["type"] == "puppet") || (specification["type"] == "puppet-class-parameter")
                  contain = false
                  if (info.key?("checks"))
                    if (info["checks"].key?(ncheck))
                      if (info["checks"][ncheck] == true)
                        contain = true
                      else
                        contain = false
                        continue = false
                      end
                    end
                  end
                  # Check confinement, if we don't match any confinement die early.
                  if specification.key?("confine")
                    confine = specification["confine"]
                    if confine != {}
                      continue = confine.all? do |confinement_setting, confinement_value|
                        case confinement_setting
                        when "module_name"
                          @callback.module_list.map {|obj| obj["name"]}.include?(confinement_value)
                        when "module_version"
                          require 'semantic_puppet'
                          rvalue = @callback.module_list.select {|obj| obj["name"] == confine["module_name"]}
                          currentver = SemanticPuppet::Version.parse(rvalue.first["version"])
                          requiredver = SemanticPuppet::VersionRange.parse(confinement_value)
                          requiredver.include?(currentver)
                        else
                          rvalue = @callback.lookup_fact(confinement_setting)
                          rretval = rvalue == confinement_value
                          rretval
                        end
                      end
                    end
                  end
                  if continue
                    if specification.key?("controls")
                      if (specification.key?("controls"))
                        specification["controls"].each do |ncontrol, subsection|
                          if (info.key?("controls"))
                            if (info["controls"].include?(ncontrol))
                              if (info["controls"][ncontrol] == true)
                                contain = true
                              else
                                contain = false
                              end
                            end
                          end

                        end
                      end
                      if (specification.key?("ces"))
                        specification["ces"].each do |nce|
                          if (info.key?("ces"))
                            if (info["ces"].key?(nce))
                              if (info["ces"][nce] == true)
                                contain = true
                              else
                                contain = false
                                continue = false
                              end
                            end
                          end
                          if (ce.key?(nce))
                            if (ce[nce].key?("controls"))
                              controls = ce[nce]["controls"]
                              controls.each do |ncontrol, subsection|

                                if (continue == true)
                                  if (info.key?("controls"))
                                    if (info["controls"].include?(ncontrol))
                                      contain = true
                                    end
                                  end
                                end
                              end
                            end
                          end
                        end
                      end
                    end
                    if contain == true
                      if specification.key?("settings")
                        if specification["settings"].key?("parameter")

                          parameter = specification["settings"]["parameter"]

                          if retval.key?(parameter)
                            #
                            # Merge
                            # XXX ToDo: Need merge settings support
                            current = retval[parameter]

                            specification["settings"].each do |key, value|
                              unless key == "parameter"
                                case current[key].class.to_s
                                when "Array"
                                  current[key] += value
                                when "Hash"
                                  current[key].merge!(value)
                                else
                                  current[key] = Marshal.load(Marshal.dump(value))
                                end
                              end
                            end

                            current["telemetry"] = current["telemetry"] + specification["telemetry"]
                          else
                            retval[parameter] = specification["settings"].merge(specification)
                          end
                        end
                      end
                    end
                  end
                end
              end
            end

          end
          retval
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

        def to_json()
          @hash.to_json
        end

        def to_yaml()
          @hash.to_yaml
        end

        def to_h()
          @hash
        end
      end
    end

    # NOTE To ensure backwards compatability, we need to take steps to ensure that
    # the v1 and v2 compilers both work without stepping on each-others' toes.
    def list_puppet_params(profile_list)
      v1_table = {}
      v2_table = {}

      # Set the keys in reverse order. This means that [ 'disa', 'nist'] would prioritize
      # disa values over nist. Only bother to store the highest priority value
      profile_list.reverse.each do |profile_map|
        # If we see no version tag, we know that this profile map must be
        # version 1, and we run the legacy code for the v1 compiler
        unless profile_map =~ /^v[0-9]+/

          @compliance_data.each do |filename, map|
            # Assume version 1 if no version is specified.
            # Due to old archaic code
            version = SemanticPuppet::Version.parse('1.0.0')

            if map.key?("version")
              version = SemanticPuppet::Version.parse(map["version"])
            end

            if version.major == 1
              result = v1_parser(profile_map, map)
              v1_table.merge!(result)
            end
          end

          # v2 application
          begin
            v2_table = v2.list_puppet_params(profile_list)
          rescue Exception => ex
            raise ex
          end
        end
      end
      table = v1_table.merge!(v2_table)

      control_list.new(table)
    end

    def v1_parser(profile, hashmap)
      table = {}
      if hashmap.key?(profile)
        hashmap[profile].each do |key, entry|
          if entry.key?("value")
            table[key] = entry
          end
        end
      end
      table
    end
    def version
      require 'semantic_puppet'
      SemanticPuppet::Version.parse("2.5.0")
    end
  end
end
