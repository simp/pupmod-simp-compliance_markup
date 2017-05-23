module Puppet::Parser::Functions
    newfunction(:compliance_map, :doc => <<-'ENDHEREDOC') do |args|
      This function provides a mechanism for mapping compliance data to
      settings in Puppet.

      It should be used **once**, after all of your classes have been included
      and is designed for use in classes to validate that parameters are
      properly set.

      The easiest method for doing this is to add it as the **last** line of
      ``site.pp``.

      When called, the parameters of all classes will be evaluated against
      global scope variables followed by data from lookup().

      The variable space against which the class parameters will be evaluated
      must be structured as the following hash:

        compliance_map :
          <compliance_profile> :
            <class_name>::<parameter> :
              'identifier' :
                - 'ID String'
              'value'      : 'Compliant Value'

      For instance, if you were mapping to NIST 800-53 in the SSH class, you
      could use something like the following in Hiera:

        compliance_map :
          nist_800_53 :
            ssh::permit_root_login :
              'identifier' :
                - 'CCE-1234'
              'value'      : false

      'value' items have some special properties. Hashes and Arrays will
      be matched using '==' in Ruby.

      Everything else will be converted to a String and can be provided a Ruby
      regular expression of the following format: 're:REGEX' where 'REGEX' does
      **not** include the starting and trailing slashes.

        Example:
          'value' : 're:oo'

          Matches: 'foo' and 'boo' but not 'bar'

      You may also add compliance data directly to your modules outside of a
      parameter mapping. This is useful if you have more advanced logic that is
      required to meet a particular internal requirement.

      NOTE: The parser does not know what line number and, possibly, what file
      the function is being called from based on the version of the Puppet
      parser being used.

      ## Global Options

      If a Hash is passed as the only argument, then this will configure the
      global report settings.

      The following options are supported:

        **:report_types**

          Default: [ 'non_compliant', 'unknown_parameters', 'custom_entries' ]

          A String, or Array that denotes which types of reports should be
          generated.

          Valid Types:
            **full**               => The full report, with all other types
                                      included.
            **non_compliant**      => Items that differ from the reference
                                      will be reported.
            **compliant**          => Compliant items will be reported.
            **unknown_resources**  => Reference resources without a
                                      system value will be reported.
            **unknown_parameters** => Reference parameters without a system
                                      value will be reported.
            **custom_entries**     => Any one-off custom calls to
                                      compliance_map will be reported.

        **:format**

        Default: 'json'

        A String that indicates what output style to use. Valid values are
        'json' and 'yaml'.

        **:client_report**

          Default: false

          A Boolean which, if set, will place a copy of the report on the
          client itself. This will ensure that PuppetDB will have a copy of the
          report for later processing.

        **:server_report**

          Default: true

          A Boolean which, if set, will store a copy of the
          report on the Server.

        **:server_report_dir**

          Default: Puppet[:vardir]/simp/compliance_reports

          An Absolute Path that specifies the location on
          the *server* where the reports should be stored.

          A directory will be created for each FQDN that
          has a report.

       **:default_map**

          Default: None

          The default map that should be used if no others can be found. This
          will probably never be manually set during normal usage via the
          compliance_markup module

      Example:
        # Only non-compilant entries and only store them on the client and the
        # server
        compliance_map({
          :report_types  => [
            'non_compliant',
            'unknown_parameters',
            'custom_entries'
          ],
          :client_report => true,
          :server_report => true
        })

      ## Custom Content

      The following optional **ordered** parameters may be used to add your own
      compliance data at any location:

        :compliance_profile => 'A String, or Array, that denotes the compliance
                                profile(s) to which you are mapping.'
        :identifier         => 'A unique identifier String or Array for the
                                policy to which you are mapping.'
        :notes              => 'An *optional* String that allows for arbitrary
                                notes to include in the compliance report'

      Example:
        if $circumstance {
          compliance_map('nist_800_53','CCE-1234','Note about this section')
          ...code that applies CCE-1234...
        }
    ENDHEREDOC

    load File.expand_path(File.dirname(__FILE__) + '/../../../puppetx/simp/compliance_map.rb')

    # There is no way to silence the global warnings on looking up a qualified
    # variable, so we're going to hack around it here.
    def self.lookup_global_silent(param)
      find_global_scope.to_hash[param]
    end

    main_config = {
      :report_types      => [
        'non_compliant',
        'unknown_parameters',
        'custom_entries'
      ],
      :format            => 'json',
      :client_report     => false,
      :server_report     => true,
      :server_report_dir => File.join(Puppet[:vardir], 'simp', 'compliance_reports'),
      :default_map => {}
    }

    # What profile are we using?
    if args && !args.empty?
      unless (args.first.is_a?(String) || args.first.is_a?(Hash))
        raise Puppet::ParseError, "compliance_map(): First parameter must be a String or Hash"
      end

      if args.first.is_a?(Hash)
        main_call = true

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

        main_config.merge!(user_config)
      else
        custom_compliance_profile    = args.shift
        custom_compliance_identifier = args.shift
        custom_compliance_notes      = args.shift

        if custom_compliance_profile && !custom_compliance_identifier
          raise Puppet::ParseError, "compliance_map(): You must pass at least two parameters"
        end

        unless custom_compliance_identifier.is_a?(String)
          raise Puppet::ParseError, "compliance_map(): Second parameter must be a compliance identifier String"
        end

        if custom_compliance_notes
          unless custom_compliance_notes.is_a?(String)
            raise Puppet::ParseError, "compliance_map(): Third parameter must be a compliance notes String"
          end
        end
      end
    else
      main_call = true
    end

    valid_formats = [
      'json',
      'yaml'
    ]

    unless valid_formats.include?(main_config[:format])
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

    unless (main_config[:report_types] - valid_report_types).empty?
      raise Puppet::ParseError, "compliance_map(): 'report_type' must include '#{valid_report_types.join(', ')}'"
    end

    # Global lookup for the legacy stack
    compliance_profiles = lookup_global_silent('compliance_profile')
    # ENC compatible lookup
    compliance_profiles ||= lookup_global_silent('compliance_markup::validate_profiles')
    # Module-level lookup
    compliance_profiles ||= catalog.resource('Class[compliance_markup]')[:validate_profiles]

    # If we didn't find any profiles to map, bail
    return unless compliance_profiles

    reference_map = lookup_global_silent('compliance_map')
    reference_map ||= Hash.new

    if ( !reference_map || reference_map.empty? )
      # If not using an ENC, check the lookup stack
      #
      # We need to check for both 'compliance_map' and
      # 'compliance_markup::compliance_map' for backward compatibility
      if self.respond_to?(:call_function)
          reference_map = call_function('lookup',['compliance_map', {'merge' => 'deep', 'default_value' => nil}])

          unless reference_map
            reference_map = call_function('lookup',['compliance_markup::compliance_map', {'merge' => 'deep', 'default_value' => nil}])
          end
      else
        raise(Puppet::ParseError, %(compliance_map(): The lookup() capability is required))
      end
    end

    # If we still don't have a reference map, we need to let the user know!
    if !reference_map || (reference_map.respond_to?(:empty) && reference_map.empty?)
      if main_config[:default_map] && !main_config[:default_map].empty?
        reference_map = main_config[:default_map]
      else
        raise(Puppet::ParseError, %(compliance_map(): Could not find the 'compliance_map' Hash at the global level or via Lookup))
      end
    end

    # Pick up our compiler hitchhiker
    # This is only needed when passing arguments. Users should no longer call
    # compliance_map() without arguments directly inside their classes or
    # definitions.
    hitchhiker = @compiler.instance_variable_get(:@compliance_map_function_data)
    if hitchhiker
      @compliance_map = hitchhiker
    else
      extra_data = {
        # Add the rest of the useful information to the map
        'fqdn'              => lookupvar('fqdn'),
        'hostname'          => lookupvar('hostname'),
        'ipaddress'         => lookupvar('ipaddress'),
        'puppetserver_info' => 'local_compile'
      }

      puppetserver_facts = lookup_global_silent('server_facts')

      if puppetserver_facts && !puppetserver_facts.empty?
        extra_data['puppetserver_info'] = puppetserver_facts
      end

      if main_config[:site_data]
        extra_data['site_data'] = main_config[:site_data]
      end

      # Create the validation report object
      # Have to break things out because jruby can't handle '::' in const_get
      @compliance_map ||= PuppetX.const_get("SIMP#{Puppet[:environment]}").const_get('ComplianceMap').new( compliance_profiles, reference_map, main_config, extra_data )
    end

    file = @source.file
    # We may not know the line number if this is at Top Scope
    line = @source.line || '<unknown>'
    name = @source.name

    # If we don't know the filename, guess....
    # This is probably because we're running in Puppet 4
    if is_topscope?
      if environment.manifest =~ /\.pp$/
        file = environment.manifest
      else
        file = File.join(environment.manifest,'site.pp')
      end
    else
      filename = name.split('::')
      filename[-1] = filename[-1] + '.pp'

      file = File.join(
        '<estimate>',
        "#{environment.modulepath.first}",
        filename
      )
    end

    # If we've gotten this far, we're ready to process *everything* and update
    # the file object.
    if main_call
      # We need to set the configuration here just in case someone called the
      # one-off mode and the @compliance_map object was already initialized.
      @compliance_map.config = main_config

      @compliance_map.process_catalog(@resource.scope.catalog)

      # Drop an entry on the server so that it can be processed when applicable.
      if main_config[:server_report]
        report_dir = File.join(main_config[:server_report_dir], lookupvar('fqdn'))
        FileUtils.mkdir_p(report_dir)

        File.open(File.join(report_dir,"compliance_report.#{main_config[:format]}"),'w') do |fh|
          if main_config[:format] == 'json'
            fh.puts(@compliance_map.to_json)
          elsif main_config[:format] == 'yaml'
            fh.puts(@compliance_map.to_yaml)
          end
        end
      end
    else
      # Here, we will only be adding custom items inside of classes or defined
      # types.

      resource_name = %(#{@resource.type}::#{@resource.title})

      # Add in custom materials if they exist

      _entry_opts = {}
      if custom_compliance_notes
        _entry_opts['notes'] = custom_compliance_notes
      end

      @compliance_map.add(
        resource_name,
        custom_compliance_profile,
        custom_compliance_identifier,
        %(#{file}:#{line}),
        _entry_opts
      )
    end

    # Embed a File resource that will place the report on the client.
    if main_config[:client_report]
      client_vardir = lookupvar('puppet_vardir')

      unless client_vardir
        raise(Puppet::ParseError, "compliance_map(): Cannot find fact `puppet_vardir`. Ensure `puppetlabs/stdlib` is installed")
      else
        compliance_report_target = %(#{client_vardir}/compliance_report.#{main_config[:format]})
      end

      # Retrieve the catalog resource if it already exists, create one if it
      # does not
      compliance_resource = catalog.resources.find{ |res|
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

        catalog.remove_resource(compliance_resource)
      else
        compliance_resource = Puppet::Parser::Resource.new(
          'file',
          compliance_report_target,
          :scope => self,
          :source => self.source
        )
        compliance_resource.set_parameter('owner',Process.uid)
        compliance_resource.set_parameter('group',Process.gid)
        compliance_resource.set_parameter('mode','0600')
      end

      if main_config[:format] == 'json'
        compliance_resource.set_parameter('content',%(#{(@compliance_map.to_json)}\n))
      elsif main_config[:format] == 'yaml'
        compliance_resource.set_parameter('content',%(#{@compliance_map.to_yaml}\n))
      end

      # Inject new information into the catalog
      catalog.add_resource(compliance_resource)
    end

    # This gets a little hairy, we need to persist the compliance map across
    # the entire compilation so we hitch a ride on the compiler.
    @compiler.instance_variable_set(:@compliance_map_function_data, @compliance_map)
  end
end
