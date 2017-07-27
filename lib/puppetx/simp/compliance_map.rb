# vim: set expandtab ts=2 sw=2:

#
# XXX TODO: We need to replace this code with one that uses the abstract compiler
# in the enforcement system. It also needs to be exportable because we have other
# downstream consumers of the compliance profile compilation system
#
# If we have one single codebase that can parse and handle the compilance profile
# system, it will be much easier for us to maintain moving forward
#
#
# BEGIN COMPLIANCE_PROFILE
#

@profile_info = Class.new(Object) do

  def ordered_hash
    Hash.new
  end

  attr_reader :api_version
  attr_accessor :config

  def initialize(valid_profiles, config)
    @err_msg = "Error: malformed compliance map, see the function documentation for details."

    @config = config

    @api_version = '1.0.1'

    @valid_profiles ||= Array(valid_profiles)

    # Collect all cache misses to sticking onto the end of the profile reports
    @ref_misses = Hash.new()

    # Collect any resources that are in our mapping but have not been included
    @unmapped_resources = Hash.new()

    # Static Information
    @compliance_map = ordered_hash
    @compliance_map['version'] = @api_version

    @compliance_map.merge!(@config[:extra_data]) if @config[:extra_data]

    @compliance_map['compliance_profiles'] = ordered_hash
    @compliance_map['site_data'] = Hash.new()

    @valid_profiles.each do |profile|
      @compliance_map['compliance_profiles'][profile] ||= Hash.new()
    end
  end

  # Set up the main data structures
  #
  # @param compliance_profiles (Array) Compliance_profile strings that are
  #   valid for this ComplianceMap
  #
  # @param compliance_mapping (Hash) Data that represents the full compliance
  #   mapping
  #
  #   Example:
  #     {
  #       'compliance' => {
  #         '<profile>' => {
  #           '<fully_qualified_class_parameter>' => '<value'
  #         }
  #       }
  #     }
  #
  def setup_compliance_map(compliance_mapping)
    @compliance_map['site_data'] = @config[:site_data] if @config[:site_data]

    @valid_profiles.sort.each do |profile|
      @compliance_map['compliance_profiles'][profile] ||= ordered_hash
      @compliance_map['compliance_profiles'][profile]['summary'] ||= ordered_hash
      @compliance_map['compliance_profiles'][profile]['compliant'] ||= ordered_hash
      @compliance_map['compliance_profiles'][profile]['non_compliant'] ||= ordered_hash
      @compliance_map['compliance_profiles'][profile]['documented_missing_resources'] ||= Array.new()
      @compliance_map['compliance_profiles'][profile]['documented_missing_parameters'] ||= Array.new()
      @compliance_map['compliance_profiles'][profile]['custom_entries'] ||= ordered_hash

      @ref_misses[profile] ||= Array.new()
      @unmapped_resources[profile] ||= Array.new()
    end
  end

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

  # Get all of the parts together for proper reporting and return the
  # result
  def format_map
    formatted_map = @compliance_map.dup
    report_types = @config[:report_types]

    @valid_profiles.each do |profile|

      # Create the summary report
      num_compliant     = formatted_map['compliance_profiles'][profile]['compliant'] ? formatted_map['compliance_profiles'][profile]['compliant'].keys.count : 0
      num_non_compliant = formatted_map['compliance_profiles'][profile]['non_compliant'] ? formatted_map['compliance_profiles'][profile]['non_compliant'].keys.count : 0

      total_checks = num_non_compliant + num_compliant
      percent_compliant = total_checks == 0 ? 0 : ((num_compliant.to_f/total_checks) * 100).round(0)

      formatted_map['compliance_profiles'][profile]['summary'] = {
        'compliant'                     => num_compliant,
        'non_compliant'                 => num_non_compliant,
        'percent_compliant'             => percent_compliant,
        'documented_missing_resources'  => @unmapped_resources[profile].count,
        'documented_missing_parameters' => @ref_misses[profile].count
      }

      unless report_types.include?('full')
        # Remove the built up content that does not apply to this system
        ['compliant', 'non_compliant', 'custom_entries'].each do |report_type|
          unless report_types.include?(report_type)
            formatted_map['compliance_profiles'][profile][report_type] = {}
          end
        end
      end

      if report_types.include?('full') || report_types.include?('unknown_resources')
        if @unmapped_resources[profile] && !@unmapped_resources[profile].empty?
          formatted_map['compliance_profiles'][profile]['documented_missing_resources'] = @unmapped_resources[profile].sort
        end
      end

      if report_types.include?('full') || report_types.include?('unknown_parameters')
        if @ref_misses && !@ref_misses[profile].empty?
          formatted_map['compliance_profiles'][profile]['documented_missing_parameters'] = @ref_misses[profile].sort
        end
      end

      # Strip out anything not relevant to the report
      formatted_map['compliance_profiles'][profile].delete_if{|k|
        val = formatted_map['compliance_profiles'][profile][k]

        val.nil? || val.empty?
      }
    end

    return formatted_map
  end

  def to_hash
    return format_map
  end

  def to_json
    require 'json'

    output = JSON.pretty_generate(format_map)

    return output
  end

  def to_yaml
    require 'yaml'

    output = format_map.to_yaml

    # Get rid of the ordered hash object information
    output.gsub!(%r( !ruby/.+CMOrderedHash), '')

    return output
  end

  # Add a custom entry to the Map
  #
  # @param resource_name (String) The name of the Puppet resource
  #
  # @param profile (String) The compliance profile under which this entry
  #   falls. The entry will not be added if this is not included in
  #   @valid_profiles
  #
  # @param identifiers (String) The compliance identifierss for the entry
  #
  # @param location (String) The 'file:line' formatted location of the
  #   function call
  #
  # @param opts (String) Custom Options
  #   * 'notes' (String) => Arbitrary notes about the entry
  #
  def add(resource_name, profile, identifiers, location, opts=ordered_hash)
    if @valid_profiles.include?(profile)
      data_hash = ordered_hash

      data_hash['location'] = location
      data_hash['identifiers'] = Array(identifiers)

      data_hash.merge!(opts)

      @compliance_map['compliance_profiles'][profile] ||= ordered_hash
      @compliance_map['compliance_profiles'][profile]['custom_entries'] ||= ordered_hash
      @compliance_map['compliance_profiles'][profile]['custom_entries'][resource_name] ||= []

      @compliance_map['compliance_profiles'][profile]['custom_entries'][resource_name] << data_hash
    end
  end

  def process_catalog(catalog, reference_map)
    setup_compliance_map(reference_map)

    target_resources = catalog.resources.select{|x| !x.parameters.empty?}

    @valid_profiles.each do |profile|
      next unless reference_map[profile]

      @unmapped_resources[profile] = reference_map[profile].keys.collect do |x|
        _tmp = x.split('::')
        _tmp.pop
        x = _tmp.join('::')
      end.sort.uniq

      # Gather up all of the possible keys in this profile
      #
      # Any items that remain are things that had a resource in Hiera but
      # were not found on the system
      @ref_misses[profile] = reference_map[profile].keys

      target_resources.each do |resource|
        human_name = resource.to_s
        resource_name = resource.name.downcase

        @unmapped_resources[profile].delete(resource_name)

        resource.parameters.keys.sort.each do |param|
          resource_ref = [resource_name, param].join('::')
          ref_entry = reference_map[profile][resource_ref]

          if ref_entry
            @ref_misses[profile].delete(resource_ref)
          else
            # If we didn't find an entry for this parameter, just skip it
            next
          end

          # Fail if the entry doesn't have the proper format
          required_metadata = ['identifiers','value']
          required_metadata.each do |md|
            raise "#{@err_msg} Failed on #{profile} profile, #{resource_ref} #{ref_entry}, metadata #{md}" if ref_entry[md].nil?
          end

          # Perform the actual matching
          ref_value = ref_entry['value']
          tgt_value = resource.parameters[param].value

          compliance_status = 'non_compliant'

          # Regular expression match
          if ref_value =~ /^re:(.+)/
            comparator = Regexp.new($1)

            if tgt_value =~ comparator
              compliance_status = 'compliant'
            end
            # Default match
          elsif ref_value.to_s.strip == tgt_value.to_s.strip
            compliance_status = 'compliant'
          end

          report_data = ordered_hash
          report_data['identifiers'] = Array(reference_map[profile][resource_ref]['identifiers'])
          report_data['compliant_value'] = ref_value
          report_data['system_value'] = tgt_value

          # If we have other optional items, sort them, and stick them
          # into the report data
          (ref_entry.keys - required_metadata).sort.each do |extra_param|
            next if extra_param.nil?
            report_data[extra_param] = ref_entry[extra_param]
          end

          @compliance_map['compliance_profiles'][profile][compliance_status][human_name] ||= ordered_hash
          @compliance_map['compliance_profiles'][profile][compliance_status][human_name]['parameters'] ||= ordered_hash
          @compliance_map['compliance_profiles'][profile][compliance_status][human_name]['parameters'][resource_ref.split('::').last] = report_data
        end
      end

      # Strip anything out of @ref_misses that has an immediate parent in
      # @unmapped_resources

      @unmapped_resources[profile].each do |to_check|
        @ref_misses[profile].delete_if do |ref|
          ref_parts = ref.split('::')
          ref_parts.pop
          ref_parts.join('::') == to_check
        end
      end
    end
  end

  private

end

#
# END COMPLIANCE PROFILE
#
def profile_info
  @profile_info
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

def get_reference_map
  reference_map = lookup_global_silent('compliance_map')
  reference_map ||= Hash.new

  if ( !reference_map || reference_map.empty? )
    # If not using an ENC, need to dig deeper

    # First, check the backwards-compatible lookup entry
    if @context.respond_to?(:call_function)
      reference_map = @context.call_function('lookup',['compliance_map', {'merge' => 'deep', 'default_value' => nil}])
    end

    # If lookup didn't find it, fish it out of the resource directly
    if ( !reference_map || reference_map.empty? )
      compliance_resource = @context.catalog.resource('Class[compliance_markup]')

      unless compliance_resource
        compliance_resource = @context.catalog.resource('Class[compliance_markup]')
      end

      if compliance_resource
        catalog_resource_map = compliance_resource['compliance_map']

        if catalog_resource_map && !catalog_resource_map.empty?
          reference_map = catalog_resource_map
        end
      end
    end
  end

  return reference_map
end

def validate_reference_map(reference_map)
  # If we still don't have a reference map, we need to let the user know!
  if !reference_map || (reference_map.respond_to?(:empty) && reference_map.empty?)
    if main_config[:default_map] && !main_config[:default_map].empty?
      reference_map = main_config[:default_map]
    else
      raise(Puppet::ParseError, %(compliance_map(): Could not find the 'compliance_map' Hash at the global level or via Lookup))
    end
  end
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

def write_server_report(config, compliance_map)
  report_dir = File.join(config[:server_report_dir], @context.lookupvar('fqdn'))
  FileUtils.mkdir_p(report_dir)

  if config[:server_report]
    File.open(File.join(report_dir,"compliance_report.#{config[:format]}"),'w') do |fh|
      if config[:format] == 'json'
        fh.puts(compliance_map.to_json)
      elsif config[:format] == 'yaml'
        fh.puts(compliance_map.to_yaml)
      end
    end
  end

  if config[:catalog_to_compliance_map]
    File.open(File.join(report_dir,'catalog_compliance_map.yaml'),'w') do |fh|
      fh.puts(compliance_map.catalog_to_map(@context.resource.scope.catalog))
    end
  end
end

def compliance_map(args, context)
  ### BEGIN MAIN PROCESSING ###
  @context = context
  main_config = process_options(args)

  # Pick up our compiler hitchhiker
  # This is only needed when passing arguments. Users should no longer call
  # compliance_map() without arguments directly inside their classes or
  # definitions.
  hitchhiker = @context.compiler.instance_variable_get(:@compliance_map_function_data)

  if hitchhiker
    compliance_map = hitchhiker

    # Need to update the config for further processing options
    compliance_map.config = main_config
  else
    compliance_profiles = get_compliance_profiles

    # If we didn't find any profiles to map, bail
    return unless compliance_profiles

    # Create the validation report object
    # Have to break things out because jruby can't handle '::' in const_get
    compliance_map = profile_info.new(compliance_profiles, main_config)
  end

  # If we've gotten this far, we're ready to process *everything* and update
  # the file object.
  if main_config[:custom_call]
    # Here, we will only be adding custom items inside of classes or defined
    # types.

    resource_name = %(#{@context.resource.type}::#{@context.resource.title})

    # Add in custom materials if they exist

    _entry_opts = {}
    if main_config[:custom][:notes]
      _entry_opts['notes'] = main_config[:custom][:notes]
    end

    file_info = custom_call_file_info

    compliance_map.add(
      resource_name,
      main_config[:custom][:profile],
      main_config[:custom][:identifier],
      %(#{file_info[:file]}:#{file_info[:line]}),
      _entry_opts
    )
  else
    reference_map = get_reference_map
    validate_reference_map(reference_map)

    compliance_map.process_catalog(@context.resource.scope.catalog, reference_map)

    # Drop an entry on the server so that it can be processed when applicable.
    write_server_report(main_config, compliance_map)

    # Embed a File resource that will place the report on the client.
    add_file_to_client(main_config, compliance_map)
  end

  # This gets a little hairy, we need to persist the compliance map across
  # the entire compilation so we hitch a ride on the compiler.
  @context.compiler.instance_variable_set(:@compliance_map_function_data, compliance_map)
end
