require 'json'
require 'json-schema'

task :validate => 'compliance:schema:validate'

namespace :'compliance:schema' do
  desc 'Validate data against the schema'
  task :validate do
    schema = JSON.load(File.read('data/compliance_profiles/schema.json'))

    maps = Dir.glob('data/compliance_profiles/**/*.json')
    no_schema = maps.delete_if { |f| f =~ /schema.json/ }
    no_schema.each do |file|
      puts 'Validating map ' + file
      profile = JSON.load(File.read(file))

      result = JSON::Validator.fully_validate(
        schema,
        profile,
        validate_schema: true
      )
      unless result.nil? or result == []
        puts result
        exit 1
      end
    end
  end
end
