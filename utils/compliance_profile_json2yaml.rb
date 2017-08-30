#!/usr/bin/env ruby

require 'json'
require 'yaml'

compliance_profiles_dir = File.expand_path(File.join(__FILE__, '../../data/compliance_profiles'))

Dir.glob(compliance_profiles_dir + '/**/*.json').each do |json_file|
  yaml_file = json_file.sub(/json$/, 'yaml')
  data = JSON.load(File.read(json_file))
  File.open(yaml_file, mode: 'w') do |f|
    f.write(YAML.dump(data))
  end
end
