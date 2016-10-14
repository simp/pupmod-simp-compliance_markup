module Puppet::Parser::Functions
  module SIMP
#### BEGIN COPIED CODE ####
# This code portion is directly pulled from ActiveSupport and is licensed unter
# the MIT License.
#
# This should be removed when we drop support for Ruby < 1.9
#
    unless defined?(OrderedHash)
      # Hash is ordered in Ruby 1.9!
      if RUBY_VERSION >= '1.9'
        OrderedHash = ::Hash
      else
        class OrderedHash < Hash #:nodoc:
          def initialize(*args, &block)
            super
            @keys = []
          end

          def self.[](*args)
            ordered_hash = new

            if (args.length == 1 && args.first.is_a?(Array))
              args.first.each do |key_value_pair|
                next unless (key_value_pair.is_a?(Array))
                ordered_hash[key_value_pair[0]] = key_value_pair[1]
              end

              return ordered_hash
            end

            unless (args.size % 2 == 0)
              raise ArgumentError.new("odd number of arguments for Hash")
            end

            args.each_with_index do |val, ind|
              next if (ind % 2 != 0)
              ordered_hash[val] = args[ind + 1]
            end

            ordered_hash
          end

          def initialize_copy(other)
            super
            # make a deep copy of keys
            @keys = other.keys
          end

          def []=(key, value)
            @keys << key if !has_key?(key)
            super
          end

          def delete(key)
            if has_key? key
              index = @keys.index(key)
              @keys.delete_at index
            end
            super
          end

          def delete_if
            super
            sync_keys!
            self
          end

          def reject!
            super
            sync_keys!
            self
          end

          def reject(&block)
            dup.reject!(&block)
          end

          def keys
            @keys.dup
          end

          def values
            @keys.collect { |key| self[key] }
          end

          def to_hash
            self
          end

          def to_a
            @keys.map { |key| [ key, self[key] ] }
          end

          def each_key
            @keys.each { |key| yield key }
          end

          def each_value
            @keys.each { |key| yield self[key]}
          end

          def each
            @keys.each {|key| yield [key, self[key]]}
          end

          alias_method :each_pair, :each

          def clear
            super
            @keys.clear
            self
          end

          def shift
            k = @keys.first
            v = delete(k)
            [k, v]
          end

          def merge!(other_hash)
            other_hash.each {|k,v| self[k] = v }
            self
          end

          def merge(other_hash)
            dup.merge!(other_hash)
          end

          def inspect
            "#<OrderedHash #{super}>"
          end

        private

          def sync_keys!
            @keys.delete_if {|k| !has_key?(k)}
          end
        end
      end
  #### END COPIED CODE ####
    end
  end

  newfunction(:compliance_map, :doc => <<-'ENDHEREDOC') do |args|
      This function provides a mechanism for mapping compliance data to
      settings in Puppet.

      It is primarily designed for use in classes to validate that parameters
      are properly set.

      When called, the parameters in the calling class will be evaluated
      against top level parameters or Hiera data, in that order.

      The variable space against which the class parameters will be evaluated
      must be structured as the following hash:

        compliance::<compliance_profile>::<class_name>::<parameter> :
          'identifier' : 'ID String'
          'value'      : 'Compliant Value'

      For instance, if you were mapping to NIST 800-53 in the SSH class, you
      could use something like the following in Hiera:

        compliance::nist_800_53::ssh::permit_root_login :
          'identifier' : 'CCE-1234'
          'value'      : false

      Alternatively, you may add compliance data to your modules outside of a
      parameter mapping. This is useful if you have more advanced logic that is
      required to meet a particular internal requirement.

      NOTE: The parser does not know what line number and, possibly, what file
      the function is being called from based on the version of the Puppet
      parser being used.

      The following optional parameters may be used to add your own compliance
      data:

        :compliance_profile => 'A String, or Array, that denotes the compliance
                                profile(s) to which you are mapping.'
        :identifier         => 'A unique identifier String or Array for the
                                policy to which you are mapping.'
        :notes              => 'An *optional* String that allows for arbitrary
                                notes to include in the compliance report'

      Example:
        if $::circumstance {
          compliance_map('nist_800_53','CCE-1234','Note about this section')
          ...code that applies CCE-1234...
        }
    ENDHEREDOC

    # There is no way to silence the global warnings on looking up a qualified
    # variable, so we're going to hack around it here.
    def self.lookup_global_silent(param)
      find_global_scope.to_hash[param]
    end

    # Set the API version for our report in case we change the format in the
    # future.
    report_api_version = '0.0.1'

    # Pick up our compiler hitchhiker
    hitchhiker = @compiler.instance_variable_get(:@compliance_map_function_data)
    if hitchhiker
      @compliance_map = hitchhiker
    else
      # Create the validation report
      unless @compliance_map
        @compliance_map = Puppet::Parser::Functions::SIMP::OrderedHash.new
        @compliance_map['version'] = report_api_version
      end

      unless @compliance_map['compliance_profiles']
        @compliance_map['compliance_profiles'] = Puppet::Parser::Functions::SIMP::OrderedHash.new
      end
    end

    # What profile are we using?
    if args && !args.empty?
      custom_compliance_profile = args.shift
      custom_compliance_identifier = args.shift
      custom_compliance_notes = args.shift

      unless custom_compliance_profile.is_a?(String)
        raise Puppet::ParseError, "compliance_map(): First parameter must be a compliance profile String"
      end

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

    compliance_profiles = Array(lookup_global_silent('compliance_profile'))

    # Obtain the file position
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

    resource_name = %(#{@resource.type}::#{@resource.title})

    # Obtain the list of variables in the class
    class_params = @resource.parameters.keys

    # Obtain the associated Hiera variables that do not match the settings in
    # the class.
    difference_params = Hash.new
    hiera_unknown = '__COMPLIANCE_UNKNOWN__'

    generate_report = false
    compliance_profiles.each do |compliance_profile|

      class_params.each do |param|
        _param = param.to_s
        _compliance_namespace = %(compliance::#{compliance_profile}::#{name}::#{_param})

        # Allow for ENC Settings
        _found_param = lookup_global_silent(_compliance_namespace)
        unless _found_param
          # If not using an ENC, look in Hiera
          # Puppet 4 compat
          if self.respond_to?(:call_function)
            _found_param = call_function('hiera',[_compliance_namespace,hiera_unknown])
          else
            _found_param = function_hiera([_compliance_namespace,hiera_unknown])
          end
        end

        _current_value = @resource.parameters[param].value

        unless _found_param == hiera_unknown
          # Compare the string version of the values, reporting differences in
          # non-string values is not useful.
          if _found_param['value'].to_s != _current_value.to_s
            difference_params[_param] = Puppet::Parser::Functions::SIMP::OrderedHash.new

            difference_params[_param]['identifier'] = _found_param['identifier']
            difference_params[_param]['compliant_value'] = _found_param['value']
            difference_params[_param]['system_value'] = _current_value

            # If we have other parameters (notes, custom entries, etc...) drag
            # them into the stack as they are.
            (_found_param.keys - ['identifier','value']).each do |extra_param|
              difference_params[_param][extra_param] = _found_param[extra_param]
            end
          end
        end
      end

      if compliance_profile && !difference_params.empty?
        unless @compliance_map['compliance_profiles'][compliance_profile]
          @compliance_map['compliance_profiles'][compliance_profile] = Puppet::Parser::Functions::SIMP::OrderedHash.new
        end

        unless @compliance_map['compliance_profiles'][compliance_profile][resource_name]
          @compliance_map['compliance_profiles'][compliance_profile][resource_name] = Puppet::Parser::Functions::SIMP::OrderedHash.new
        end
      end

      include_custom_compliance_profile = (custom_compliance_profile && compliance_profiles.include?(custom_compliance_profile))

      if include_custom_compliance_profile
        unless @compliance_map['compliance_profiles'][custom_compliance_profile]
          @compliance_map['compliance_profiles'][custom_compliance_profile] = Puppet::Parser::Functions::SIMP::OrderedHash.new
        end

        unless @compliance_map['compliance_profiles'][custom_compliance_profile][resource_name]
          @compliance_map['compliance_profiles'][custom_compliance_profile][resource_name] = Puppet::Parser::Functions::SIMP::OrderedHash.new
        end
      end

      generate_report = false
      # Perform the parameter mapping
      unless difference_params.empty?
        unless @compliance_map['compliance_profiles'][compliance_profile][resource_name]['parameters']
          @compliance_map['compliance_profiles'][compliance_profile][resource_name]['parameters'] = Puppet::Parser::Functions::SIMP::OrderedHash.new
        end

        difference_params.keys.each do |param|
          @compliance_map['compliance_profiles'][compliance_profile][resource_name]['parameters'][param] = difference_params[param]
        end

        generate_report = true
      end

      # Add in custom materials if they exist
      if include_custom_compliance_profile
        unless @compliance_map['compliance_profiles'][custom_compliance_profile][resource_name]['custom_entries']
          @compliance_map['compliance_profiles'][custom_compliance_profile][resource_name]['custom_entries'] = []
        end

        _data_hash = Puppet::Parser::Functions::SIMP::OrderedHash.new

        _data_hash['location'] = %(#{file}:#{line})
        _data_hash['identifier'] = custom_compliance_identifier

        if custom_compliance_notes
          _data_hash['notes'] = custom_compliance_notes
        end
        @compliance_map['compliance_profiles'][custom_compliance_profile][resource_name]['custom_entries'] |= [_data_hash]

        generate_report = true
      end
    end

    # This will be useful for a future iteration of the software.
    #if generate_report
      if Facter.value(:puppet_vardir).nil?
        raise Puppet::ParseError, "compliance_map(): Cannot find fact `puppet_vardir`. Ensure `puppetlabs/stdlib` is installed"
      else
        compliance_report_target = %(#{Facter.value(:puppet_vardir)}/compliance_report.yaml)
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

      compliance_resource.set_parameter('content',%(#{@compliance_map.to_yaml}\n))

      # Inject new information into the catalog
      catalog.add_resource(compliance_resource)

      # This gets a little hairy, we need to persist the compliance map across
      # the entire compilation so we hitch a ride on the compiler.
      @compiler.instance_variable_set(:@compliance_map_function_data, @compliance_map)
    #end
  end
end
