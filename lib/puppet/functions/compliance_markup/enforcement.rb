# vim: set expandtab ts=2 sw=2:
Puppet::Functions.create_function(:'compliance_markup::enforcement') do
  dispatch :hiera_enforcement do
    param "String", :key
    param "Hash", :options
    param "Puppet::LookupContext", :context
  end
  def initialize(closure_scope, loader)
    filename = File.dirname(File.dirname(File.dirname(File.dirname(__FILE__)))) + "/puppetx/simp/compliance_mapper.rb"
    self.instance_eval(File.read(filename),filename)
    super(closure_scope, loader)
  end
  def hiera_enforcement(key, options, context)
    retval = nil
    @context = context
    begin
      retval = enforcement(key) do |key, default|
         call_function('lookup', key, { "default_value" => default})
      end
    rescue => e
      unless (e.class.to_s == "ArgumentError")
        debug("Threw error #{e.to_s}")
      end
      context.not_found
    end
    retval
  end
  def debug(message)
    @context.explain() { "debug: #{message}" }
  end
  def cache(key, value)
    @context.cache(key, value)
  end
  def cached_value(key)
    @context.cached_value(key)
  end
  def cache_has_key(key)
    @context.cache_has_key(key)
  end
end
