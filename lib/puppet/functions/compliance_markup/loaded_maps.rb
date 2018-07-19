Puppet::Functions.create_function(:'compliance_markup::loaded_maps') do
  def initialize(closure_scope, loader)
    filename = File.dirname(File.dirname(File.dirname(File.dirname(__FILE__)))) + '/puppetx/simp/compliance_mapper.rb'
    self.instance_eval(File.read(filename),filename)
    super(closure_scope, loader)
  end
  def loaded_maps()
    retval = nil
    profile_compiler = compiler_class.new(self)
    profile_compiler.load  do |k, default|
      call_function('lookup', k, { 'default_value' => default})
    end
    retval = profile_compiler.compliance_data.keys
  end
  def codebase()
    'compliance_markup::loaded_maps'
  end
  def environment()
    closure_scope.environment.name.to_s
  end
  def debug(message)
    false
  end
  def cache(key, value)
    nil
  end
  def cached_value(key)
    nil
  end
  def cache_has_key(key)
    false
  end
  def cached_file_data(path)
    File.read(path)
  end
  def lookup_fact(fact)
    closure_scope.lookupvar("facts")[fact]
  end
  def module_list
    closure_scope.environment.modules.map { |obj| { "name" => obj.metadata["name"], "version" => obj.metadata["version"] } }
  end
end
