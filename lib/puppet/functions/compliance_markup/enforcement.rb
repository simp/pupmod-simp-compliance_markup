Puppet::Functions.create_function(:'compliance_markup::enforcement', Puppet::Functions::InternalFunction) do
  dispatch :hiera_enforcement do
    scope_param()
    param "String", :key
    param "Hash", :options
    param "Puppet::LookupContext", :context
  end

  def hiera_enforcement(scope, key, options, context)
    filename = File.expand_path('../../../../puppetx/simp/compliance_mapper.rb', __FILE__)
    self.instance_eval(File.read(filename), filename)

    retval = nil

    # This is needed to prevent infinite looping. Usually, the lookup function
    # is called from different modules and, therefore, requires different
    # scoping. However, in our case, we're actually looking across modules and
    # need to maintain the same context at all times to ensure that caching
    # works properly.
    if @context
      # This should never be called, but we're going to be extra safe and reload
      # the underlying mapper code if it is.
      if @context.environment_name != context.environment_name
        filename = File.expand_path('../../../../puppetx/simp/compliance_mapper.rb', __FILE__)
        self.instance_eval(File.read(filename), filename)

        @context = context
      end
    else
      @context ||= context
    end

    # Quick return if we already have a cached value for the key.
    return cached_value(key) if cached_value(key)

    begin
      retval = enforcement(key, @context) do |k, default|
         call_function('lookup', k, { 'default_value' => default})
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
    if (!@context.nil?)
      @context.not_found
    else
      throw :no_such_key
    end
  end

  def debug(message)
    if (!@context.nil?)
      @context.explain() { "#{message}" }
    end
  end

  def cache(key, value)
    if (!@context.nil?)
      @context.cache(key, value)
    end
  end

  def cached_entries
    @context.cached_entries
  end

  def cached_value(key)
    if (!@context.nil?)
      @context.cached_value(key)
    end
  end

  def cache_has_key(key)
    if (!@context.nil?)
      @context.cache_has_key(key)
    else
      false
    end
  end
  def lookup_fact(fact)
    closure_scope.lookupvar("facts").dig(*fact.split('.'))
  end
  def module_list
    closure_scope.environment.modules.map { |obj| { "name" => obj.metadata["name"], "version" => obj.metadata["version"] } }
  end

  def cache_all(hash)
    @context.cache_all(hash)
  end
end
