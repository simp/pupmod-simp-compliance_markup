#!/usr/bin/env ruby

require 'json'
require 'yaml'

compliance_profiles_dir = File.expand_path(File.join(__FILE__, '../../data/compliance_profiles'))

Dir.glob(compliance_profiles_dir + '/**/*.yaml').each do |yaml_file|
  json_file = yaml_file.sub(/yaml$/, 'json')
  data = YAML.load_file(yaml_file)
  File.open(json_file, mode: 'w') do |f|
    f.write(JSON.pretty_generate(data))
  end
end
