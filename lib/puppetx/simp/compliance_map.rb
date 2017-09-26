# vim: set expandtab ts=2 sw=2:


#
# BEGIN COMPLIANCE_PROFILE
#


  def catalog_to_map(catalog)
    catalog_map = Hash.new()

    catalog_map['compliance_map::percent_sign'] = '%'
    catalog_map['compliance_map'] = {
      'version'                => @api_version,
      'generated_via_function' => Hash.new()
    }

    catalog.resources.each do |resource|
      # Ignore our own nonsense
      next if resource.name == 'Compliance_markup'

      if resource.name.is_a?(String) && (resource.name[0] =~ /[A-Z]/) && resource.parameters
        resource.parameters.each do |param_array|
          param = param_array.last

          param_name = %{#{resource.name}::#{param.name}}.downcase

          # We only want things with values
          next if param.value.nil?

          catalog_map['compliance_map']['generated_via_function'][param_name] = {
            'identifiers' => ['GENERATED'],
            'value'       => param.value
          }
        end
      end
    end

    return catalog_map.to_yaml
  end


# There is no way to silence the global warnings on looking up a qualified
# variable, so we're going to hack around it here.
def lookup_global_silent(param)
  @context.find_global_scope.to_hash[param]
end

def process_options(args)
  config = {
    :custom_call              => false,
    :report_types             => [
      'non_compliant',
      'unknown_parameters',
      'custom_entries'
    ],
    :format                   => 'json',
    :client_report            => false,
    :server_report            => true,
    :server_report_dir        => File.join(Puppet[:vardir], 'simp', 'compliance_reports'),
    :default_map              => {},
    :catalog_to_compliance_map => false
  }

  # What profile are we using?
  if args && !args.empty?
    unless (args.first.is_a?(String) || args.first.is_a?(Hash))
      raise Puppet::ParseError, "compliance_map(): First parameter must be a String or Hash"
    end

    # This is used during the main call
    if args.first.is_a?(Hash)
      # Convert whatever was passed in to a symbol so that the Hash merge
      # works properly.
      user_config = Hash[args.first.map{|k,v| [k.to_sym, v] }]
      if user_config[:report_types]
        user_config[:report_types] = Array(user_config[:report_types])
      end

      # Takes care of things that have been set to 'undef' in Puppet
      user_config.delete_if{|k,v|
        v.nil? || v.is_a?(Symbol)
      }

      config.merge!(user_config)

      # This is used for custom content
    else
      config[:custom_call] = true
      config[:custom] = {
        :profile    => args.shift,
        :identifier => args.shift,
        :notes      => args.shift
      }

      if config[:custom][:profile] && !config[:custom][:identifier]
        raise Puppet::ParseError, "compliance_map(): You must pass at least two parameters"
      end

      unless config[:custom][:identifier].is_a?(String)
        raise Puppet::ParseError, "compliance_map(): Second parameter must be a compliance identifier String"
      end

      unless config[:custom][:notes].is_a?(String)
        raise Puppet::ParseError, "compliance_map(): Third parameter must be a compliance notes String"
      end
    end
  end

  valid_formats = [
    'json',
    'yaml'
  ]

  unless valid_formats.include?(config[:format])
    raise Puppet::ParseError, "compliance_map(): 'valid_formats' must be one of: '#{valid_formats.join(', ')}'"
  end

  valid_report_types = [
    'full',
    'non_compliant',
    'compliant',
    'unknown_resources',
    'unknown_parameters',
    'custom_entries'
  ]

  unless (config[:report_types] - valid_report_types).empty?
    raise Puppet::ParseError, "compliance_map(): 'report_type' must include '#{valid_report_types.join(', ')}'"
  end

  config[:extra_data] = {
    # Add the rest of the useful information to the map
    'fqdn'              => @context.lookupvar('fqdn'),
    'hostname'          => @context.lookupvar('hostname'),
    'ipaddress'         => @context.lookupvar('ipaddress'),
    'puppetserver_info' => 'local_compile'
  }

  puppetserver_facts = lookup_global_silent('server_facts')

  if puppetserver_facts && !puppetserver_facts.empty?
    config[:extra_data]['puppetserver_info'] = puppetserver_facts
  end

  if config[:site_data]
    unless config[:site_data].is_a?(Hash)
      raise Puppet::ParseError, %(compliance_map(): 'site_data' must be a Hash)
    end
  end

  return config
end

def get_compliance_profiles
  # Global lookup for the legacy stack
  compliance_profiles = lookup_global_silent('compliance_profile')
  # ENC compatible lookup
  compliance_profiles ||= lookup_global_silent('compliance_markup::validate_profiles')
  # Module-level lookup
  compliance_profiles ||= @context.catalog.resource('Class[compliance_markup]')[:validate_profiles]

  return compliance_profiles
end

def add_file_to_client(config, compliance_map)
  if config[:client_report]
    client_vardir = @context.lookupvar('puppet_vardir')

    unless client_vardir
      raise(Puppet::ParseError, "compliance_map(): Cannot find fact `puppet_vardir`. Ensure `puppetlabs/stdlib` is installed")
    else
      compliance_report_target = %(#{client_vardir}/compliance_report.#{config[:format]})
    end

    # Retrieve the catalog resource if it already exists, create one if it
    # does not
    compliance_resource = @context.catalog.resources.find{ |res|
      res.type == 'File' && res.name == compliance_report_target
    }

    if compliance_resource
      # This is a massive hack that should be removed in the future.  Some
      # versions of Puppet, including the latest 3.X, do not check to see if
      # a resource has the 'remove' capability defined before calling it.  We
      # patch in the method here to work around this issue.
      unless compliance_resource.respond_to?(:remove)
        # Using this instead of define_singleton_method for Ruby 1.8 compatibility.
        class << compliance_resource
          self
        end.send(:define_method, :remove) do nil end
      end

      @context.catalog.remove_resource(compliance_resource)
    else
      compliance_resource = Puppet::Parser::Resource.new(
        'file',
        compliance_report_target,
        :scope => @context,
        :source => @context.source
      )
      compliance_resource.set_parameter('owner',Process.uid)
      compliance_resource.set_parameter('group',Process.gid)
      compliance_resource.set_parameter('mode','0600')
    end

    if config[:format] == 'json'
      compliance_resource.set_parameter('content',%(#{(compliance_map.to_json)}\n))
    elsif config[:format] == 'yaml'
      compliance_resource.set_parameter('content',%(#{compliance_map.to_yaml}\n))
    end

    # Inject new information into the catalog
    @context.catalog.add_resource(compliance_resource)
  end
end


def write_server_report(config, report)
  report_dir = File.join(config[:server_report_dir], @context.lookupvar('fqdn'))
  FileUtils.mkdir_p(report_dir)

  if config[:server_report]
    File.open(File.join(report_dir,"compliance_report.#{config[:format]}"),'w') do |fh|
      if config[:format] == 'json'
        fh.puts(report.to_json)
      elsif config[:format] == 'yaml'
        fh.puts(report.to_yaml)
      end
    end
  end
  if config[:catalog_to_compliance_map]
    File.open(File.join(report_dir,'catalog_compliance_map.yaml'),'w') do |fh|
      fh.puts(catalog_to_map(@context.resource.scope.catalog))
    end
  end
end

def compliance_map(args, context)
  @context = context
  if (@custom_entries == nil)
    @custom_entries = {}
  end
  @catalog = @context.resource.scope.catalog
  profile_compiler = compiler_class.new(self)
  profile_compiler.load do |key, default|
    @context.call_function('lookup', [key, {"default_value" => default}])
  end

  main_config = process_options(args)
  if main_config[:custom_call]
    add_custom_entries(main_config);
  else
    report_types = main_config[:report_types]
    if report_types.include?('full')
      report_types << 'unknown_resources'
      report_types << 'unknown_parameters'
      report_types << 'compliant'
      report_types << 'non_compliant'
      report_types << 'custom_entries'
    end
    report = main_config[:extra_data].dup
    report["version"] = '1.0.1';
    report["compliance_profiles"] = {}
    profile_list = get_compliance_profiles
    unless profile_list.class.to_s == "Array"
      profile_list = [ profile_list ]
    end
      profile_list.each do |profile|
        profile_report = {}
        report["compliance_profiles"][profile] = profile_report
        profile_report["documented_missing_parameters"] = []
        profile_report["compliant"] = {}
        profile_report["non_compliant"] = {}
        profile_map = profile_compiler.list_puppet_params([profile]).cook do |data|
          {"value" => data["value"], "identifiers" => data["identifiers"]}
        end
        parameters = {}
        classes = {}
        @catalog.resources.each do |obj|
          classname = obj.title.downcase
          obj.parameters.each do |parameter, data|
            fully_qualified_parameter = classname + "::" + parameter.to_s
            if (profile_map.key?(fully_qualified_parameter))
              profile_settings = profile_map[fully_qualified_parameter]
              current_value = data.value
              # XXX ToDo This should be improved to allow for validators to be specified
              # instead of forcing regexes to be in values (as it breaks enforcement)
              # ie, functions or built ins.
              if (profile_settings.key?("value"))
                expected_value = profile_settings["value"]
                result = {
                    "compliant_value" => expected_value,
                    "system_value" => current_value,
                }
                if (profile_settings.key?("identifiers"))
                 result["identifiers"] = profile_settings["identifiers"]
                end
                classkey = "#{obj.type}[#{obj.title}]"
                if (expected_value =~ /^re:(.+)/)
                  if (current_value =~ Regexp.new($1))
                    section = "compliant"
                  else
                    section = "non_compliant"
                  end
                else
                  if (current_value == expected_value)
                    section = "compliant"
                  else
                    section = "non_compliant"
                  end
                end
                if report_types.include?(section)
                  unless (profile_report[section].key?(classkey))
                    profile_report[section][classkey] = {}
                    profile_report[section][classkey]["parameters"] = {}
                  end
                    profile_report[section][classkey]["parameters"][parameter.to_s] = result

                end
              end
            else
               parameters[fully_qualified_parameter] = true
               classes[classname] = true
            end
          end
        end

        {
            'unknown_parameters' => 'documented_missing_parameters',
            'unknown_resources' => 'documented_missing_resources'
        }.each do |type, name|
          if report_types.include?(type)
            profile_report[name] = []
            profile_map.select do |key, value|
              unless parameters.key?(key)
                profile_report[name] << key
              end
            end
          end
        end

        profile_report["custom_entries"] = @custom_entries[profile]

        profile_report['summary'] = summary(profile_report)

        # Clean up empty arrays and hashes
        [ 'non_compliant', 'compliant', 'documented_missing_parameters', "documented_missing_resources"].each do |key|
          if profile_report[key] == {}
            profile_report.delete(key);
          end
          if profile_report[key] == []
            profile_report.delete(key);
          end
        end
    end
    write_server_report(main_config, report)
    add_file_to_client(main_config, report)
  end
end

#
# Create a summary from a profile report.
#

def summary(profile_report)
  num_compliant = profile_report['compliant'] ? profile_report['compliant'].keys.count : 0
  num_non_compliant = profile_report['non_compliant'] ? profile_report['non_compliant'].keys.count : 0

  total_checks = num_non_compliant + num_compliant
  percent_compliant = total_checks == 0 ? 0 : ((num_compliant.to_f/total_checks) * 100).round(0)

  {
      'compliant' => num_compliant,
      'non_compliant' => num_non_compliant,
      'percent_compliant' => percent_compliant,
      'documented_missing_parameters' => profile_report["documented_missing_parameters"].count
  }
end

def add_custom_entries(main_config)
  # XXX ToDo
  # We need to decide if this is actually necessary. If the compliance profiles are authoritative
  # then having to evaluate a catalog to get all values makes no sense
  file_info = custom_call_file_info
  value = {
      "identifiers" => main_config[:custom][:identifier],
      "location" => %(#{file_info[:file]}:#{file_info[:line]})
  }
  if main_config[:custom][:notes]
    value['notes'] = main_config[:custom][:notes]
  end
  profile = main_config[:custom][:profile]
  resource_name = %(#{@context.resource.type}::#{@context.resource.title})
  unless (@custom_entries.key?(profile))
    @custom_entries[profile] = {}
  end
  unless (@custom_entries[profile].key?(resource_name))
    @custom_entries[profile][resource_name] = []
  end
  @custom_entries[profile][resource_name] << value
end

def custom_call_file_info
  file_info = {
      :file => @context.source.file,
      # We may not know the line number if this is at Top Scope
      :line => @context.source.line || '<unknown>',
  }

  # If we don't know the filename, guess....
  # This is probably because we're running in Puppet 4
  if @context.is_topscope?
    # Cast this to a string because it could potentially be a symbol from
    # the bowels of Puppet, or 'nil', or whatever and is purely
    # informative.
    env_manifest = "#{@context.environment.manifest}"

    if env_manifest =~ /\.pp$/
      file = env_manifest
    else
      file = File.join(env_manifest,'site.pp')
    end
  else
    filename = @context.source.name.split('::')
    filename[-1] = filename[-1] + '.pp'

    file = File.join(
        '<estimate>',
        "#{@context.environment.modulepath.first}",
        filename
    )
  end

  return file_info
end
def cache(key, value)
  if @hash == nil
    @hash = {}
  end
  @hash[key] = value
end
def cached_value(key)
  if @hash == nil
    @hash = {}
  end
  @hash[key]
end
def cache_has_key(key)
  if @hash == nil
    @hash = {}
  end
  @hash.key?(key)
end