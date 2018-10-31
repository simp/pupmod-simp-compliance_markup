Puppet::Functions.create_function(:'compliance_markup::enforcement') do
  dispatch :hiera_enforcement do
    param "String", :key
    param "Hash", :options
    param "Puppet::LookupContext", :context
    end
  dispatch :hiera_enforcement do
    param "String", :key
    param "Hash", :options
    param "Undef", :context
  end
  def initialize(closure_scope, loader)
    filename = File.expand_path('../../../../puppetx/simp/compliance_mapper.rb', __FILE__)

    self.instance_eval(File.read(filename),filename)
    super(closure_scope, loader)
  end
  def hiera_enforcement(key, options, context)
    retval = nil
    @context = context
    begin
      retval = enforcement(key) do |k, default|
         call_function('lookup', k, { 'default_value' => default})
      end
    rescue => e
      unless (e.class.to_s == 'ArgumentError')
        debug("Threw error #{e.to_s}")
      end
      not_found
    end
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
    closure_scope.lookupvar("facts")[fact]
  end
  def module_list
    closure_scope.environment.modules.map { |obj| { "name" => obj.metadata["name"], "version" => obj.metadata["version"] } }
  end
end
