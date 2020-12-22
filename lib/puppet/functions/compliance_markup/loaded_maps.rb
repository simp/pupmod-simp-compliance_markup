# Returns the compliance data keys from the loaded compliance maps
Puppet::Functions.create_function(:'compliance_markup::loaded_maps', Puppet::Functions::InternalFunction) do

  # @return [Nil]
  dispatch :loaded_maps do
    scope_param()
  end

  def loaded_maps(scope)
    filename = File.dirname(File.dirname(File.dirname(File.dirname(__FILE__)))) + '/puppetx/simp/compliance_mapper.rb'
    self.instance_eval(File.read(filename),filename)

    profile_compiler = compiler_class.new(self)
    profile_compiler.load  do |k, default|
      call_function('lookup', k, { 'default_value' => default})
    end

    profile_compiler.compliance_data.keys
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
end
