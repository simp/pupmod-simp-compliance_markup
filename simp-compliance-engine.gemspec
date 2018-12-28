$LOAD_PATH.unshift File.expand_path('../lib', __FILE__)

module Simp
  class Helpers
    def self.get_param(param, command)
      file = "#{File.dirname(__FILE__)}/.gem_#{param}"
      if (File.exists?(file))
        info = File.read(file)
      else
        info = `#{command}`
        File.open(file, "w") do |f|
          f.write(info)
        end
      end
      puts info
      info
    end
  end
end

Gem::Specification.new do |s|
  s.name = 'simp-compliance-engine'
  ver = Simp::Helpers.get_param("version", "git describe --always --dirty")
  date = Simp::Helpers.get_param("date", "git show -s --date=short --format=%cd HEAD")
  s.date = date
  s.version = ver
  s.summary = 'SIMP Metadata Library'
  s.description = 'A library for accessing the SIMP metadata format for the simp project'
  s.authors = [
    "SIMP Project"
  ]
  s.executables      = `git ls-files -- exe/*`.split("\n").map{ |f| File.basename(f) }
  s.bindir           = 'exe'
  s.email = 'simp@simp-project.org'
  s.license = 'Apache-2.0'
  s.homepage = 'https://github.com/simp/pupmod-simp-compliance_markup'
  s.files = Dir['Rakefile', '{bin,lib,data}/**/*', 'README*','*.gemspec','*.md','CONTRIBUTORS','Gemfile','LICENSE','NOTICE.TXT', '.gem_version', '.gem_date']
  s.add_runtime_dependency 'semantic_puppet'
end
