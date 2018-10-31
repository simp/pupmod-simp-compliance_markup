Puppet::Functions.create_function(:'compliance_markup::enforcement') do
  dispatch :hiera_enforcement do
    param "String", :key
    param "Hash", :options
    param "Puppet::LookupContext", :context
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
      context.not_found
    end
    retval
  end
  def codebase()
    'compliance_markup::enforcement'
  end
  def environment()
    closure_scope.environment.name.to_s
  end
  def debug(message)
    @context.explain() { "#{message}" }
  end
  def cache?
    if (!@context.nil?)
      true
    else
      false
    end
  end
  def cache(key, value)
    @context.cache(key, value)
  end
  def cache_has_key(key)
    if (!@context.nil?)
      @context.cache_has_key(key)
    else
      false
    end
  end
  def cached_file_data(path)
    data = nil
    if (!@context.nil?)
      @context.cached_file_data(path) do |contents|
        data = contents
      end
    else
      data = File.read(path)
    end
    data
  end
  def cached_value(key)
    @context.cached_value(key)
  end
  def cache_has_key(key)
    @context.cache_has_key(key)
  end
end
