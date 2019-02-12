# Add compliance_mapper-specific syntax checks to `rake syntax

# frozen_string_literal: true

namespace :syntax do
  namespace :compliance_mapper do
    def syntax_check(task, glob)
      warn "---> #{task.name}"
      Dir.glob(glob).map do |file|
        puts '------| Attempting to load: ' + file
        yield(file)
      end
    end

    desc 'Syntax check for JSON files under data/'
    task :json do |t|
      require 'json'
      syntax_check(t, 'data/**/*.json') { |j| JSON.parse(File.read(j)) }
    end

    desc 'Syntax check for YAML files under data/'
    task :yaml do |t|
      require 'yaml'
      syntax_check(t, 'data/**/*.y{,a}ml') { |y| YAML.safe_load(File.new(y)) }
    end
  end
end

task syntax: [
  'syntax:compliance_mapper:json',
  'syntax:compliance_mapper:yaml'
]
