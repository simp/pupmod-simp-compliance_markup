#!/usr/bin/env ruby

require 'yaml'

def deep_merge(old, new)
  old.merge(new) { |key, val1, val2|
    if val1.kind_of?(Hash) and val2.kind_of?(Hash)
      deep_merge(val1, val2)
    elsif val1.kind_of?(Array) and val2.kind_of?(Array)
      val1 & val2
    else
      val2
    end
  }
end

el6 = YAML.load_file('checks-el6.yaml')
el7 = YAML.load_file('checks-el7.yaml')

combined = {
  'version' => '2.0.0',
  'checks'  => {},
}

el6['checks'].keys.each do |k|
  key = k.sub(%r{\.el6$}, '')
  if el7['checks'].key?(key)
    if el6['checks'][k]['settings']['value'] == el7['checks'][key]['settings']['value']
      combined['checks'][key] = deep_merge(el6['checks'][k], el7['checks'][key])
      el6['checks'].delete(k)
      el7['checks'].delete(key)
      combined['checks'][key].delete('confine')
    end
  else
    combined['checks'][key] = el6['checks'][k]
    el6['checks'].delete(k)
  end
end

combined = deep_merge(combined, el6)
combined = deep_merge(combined, el7)

File.open('checks.yaml', 'w') do |fh|
  fh.puts(combined.to_yaml)
end
