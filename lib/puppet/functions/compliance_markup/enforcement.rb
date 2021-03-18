# Hiera entry point for the SIMP Compliance Engine
#
# To activate this hiera backend, add the following to your `hiera.yaml`:
#
# ```yaml
# ---
# version: 5
# hierarchy:
#   - name: SIMP Compliance Engine
#     lookup_key: compliance_markup::enforcement
#     # All options are optional
#     options:
#       # Ignore all default data dirs and use these instead
#       data_dirs:
#         - /fully/qualified/data_dir
#       # Add all items from these paths to the data sources
#       # Stacks on both `data_dirs` and the inbuilt paths
#       aux_paths:
#         - /fully/qualified/path
# ```
#
# Then, tell it what profile(s) to enforce by adding the following to your Hiera
# configuration for your target node(s):
#
# ```yaml
# ---
# # Enforce your custom company profile, then the STIG, then the NIST 800-53 Rev 4
# compliance_markup::enforcement:
#   - 'your_company_profile'
#   - 'disa_stig'
#   - 'nist_800_53:rev4'
# ```
Puppet::Functions.create_function(:'compliance_markup::enforcement') do
  # @param key
  #   The key to look up in the backend
  # @param options
  #   Required by Hiera
  # @param context
  #   The context in which the Hiera backend is being called
  #
  # @return [Any]
  #   The discovered value or Undef if not found
  dispatch :hiera_enforcement do
    param "String", :key
    param "Hash", :options
    param "Puppet::LookupContext", :context
  end

  def hiera_enforcement(key, options, context)
    filename = File.expand_path('../../../../puppetx/simp/compliance_mapper.rb', __FILE__)
    self.instance_eval(File.read(filename), filename)

    retval = nil

    @context = context

    begin
      # Parameters are frozen
      options_dup = Marshal.load(Marshal.dump(options))

      retval = enforcement(key, @context, options_dup) do |k, default|
         call_function('lookup', k, { 'default_value' => default })
      end
    rescue => e
      unless (e.class.to_s == 'ArgumentError')
        debug("Threw error #{e.to_s}")
      end

      not_found
    end

    # Add the key to the cache if we found something
    cache(key, retval) if retval

    retval
  end

  def codebase()
    'compliance_markup::enforcement'
  end

  def environment()
    closure_scope.environment.name.to_s
  end

  def not_found()
    @context.not_found
  end

  def debug(message)
    @context.explain() { "#{message}" }
  end

  def cache(key, value)
    @context.cache(key, value)
  end

  def cache_all(hash)
    @context.cache_all(hash)
  end

  def cached_entries
    @context.cached_entries
  end

  def cached_value(key)
    @context.cached_value(key)
  end

  def cache_has_key(key)
    @context.cache_has_key(key)
  end

  def lookup_fact(fact)
    begin
      call_function('dig', closure_scope.lookupvar('facts'), *fact.split('.'))
    rescue ArgumentError
      nil
    end
  end

  def module_list
    closure_scope.environment.modules.map { |obj| { "name" => obj.metadata["name"], "version" => obj.metadata["version"] } }
  end
end
