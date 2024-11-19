#!/usr/bin/env ruby

require 'json'
require 'yaml'

output_hash = {
  'controls' => {},
  'ce' => {},
  'checks' => {},
  'profiles' => {},
}
params = {}
Dir.glob('../data/compliance_profiles/**/*.json') do |filename|
  data = JSON.parse(File.read(filename))
  data['compliance_markup::compliance_map'].each do |profile, value|
    next unless profile != 'version'
    value.each do |k, v|
      unless params.key?(k)
        params[k] = []
      end
      duplicate = false
      v['profiles'] = [ profile ]
      params[k].each do |entry|
        next unless entry['value'] == v['value']
        duplicate = true
        entry['identifiers'].concat(v['identifiers'])
        entry['identifiers'] = entry['identifiers'].uniq
        entry['profiles'] << profile
        entry['profiles'] = entry['profiles'].uniq
      end
      if duplicate == false
        params[k] << v
      end
    end
  end
end

params.each do |key, value|
  if value.size == 1
    check_name = "oval:simp.shared.#{key}:def:1"
    output_hash['checks'][check_name] = value[0]
  else
    output = "#{key} = "
    value.each do |entry|
      output += "#{entry['profiles'][0]}:#{entry['value']} "
      check_name = if entry['profiles'].include?('disa_stig')
                     "oval:simp.disa.#{key}:def:1"
                   else
                     "oval:simp.nist.#{key}:def:1"
                   end
      output_hash['checks'][check_name] = entry
    end
    puts output
  end
end

output_hash['checks'].each do |checkname, check|
  controls = {}
  check['identifiers'].each do |identifier|
    ident = identifier.split('(')[0]
    case ident
    when %r{RHEL-}
      break
    when %r{CCI-}
      break
    when %r{SRG-}
      break
    else
      control = ident
    end
    unless output_hash['controls'].key?(control)
      family = control.split('-')[0]
      output_hash['controls'][control] = {
        'family' => family
      }
    end
    controls[control] = 0
  end
  configuration_element = {
    'controls' => controls
  }
  output_hash['ce'][checkname] = configuration_element
  profiles = check['profiles']
  profiles.each do |profilename|
    unless output_hash['profiles'].key?(profilename)
      output_hash['profiles'][profilename] = {
        'ces' => []
      }
    end
    output_hash['profiles'][profilename]['ces'] << checkname
  end
end

output_hash['profiles'].each_value do |value|
  value['ces'].sort!
end
