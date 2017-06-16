# vim: set expandtab ts=2 sw=2:
require 'spec_helper_acceptance'
require 'semantic_puppet'
test_name 'compliance_markup class enforcement'

describe 'compliance_markup class enforcement' do

  def set_profile_data_on(host, hiera_yaml, profile_data)

    Dir.mktmpdir do |dir|
      tmp_yaml = File.join(dir, 'hiera.yaml')
      File.open(tmp_yaml, 'w') do |fh|
        fh.puts hiera_yaml
      end
      host.do_scp_to(tmp_yaml, '/etc/puppetlabs/puppet/hiera.yaml', {})
    end

    Dir.mktmpdir do |dir|
      File.open(File.join(dir, "default" + '.yaml'), 'w') do |fh|
        fh.puts(profile_data)
        fh.flush

        default_file = "/etc/puppetlabs/code/environments/production/hieradata/default.yaml"

        host.do_scp_to(dir + "/default.yaml", default_file, {})
      end
    end
  end

  let(:base_manifest) {
    <<-EOS
      include 'useradd'
    EOS
  }

  let(:base_hieradata) { <<-EOF
---
compliance_markup::enforcement:
  - disa

compliance_markup::compliance_map:
  version: 1.0.0
  disa:
    useradd::shells:
      identifiers:
        - FOO
        - BAR
      notes: Nothing fun really
      value:
        - /bin/disa
  nist:
    useradd::shells:
      identifiers:
        - FOO2
        - BAR2
      notes: Nothing fun really
      value:
        - /bin/nist
                         EOF
  }
  let(:extra_hieradata) { <<-EOF
---
compliance_markup::enforcement:
  - nist
  - disa

compliance_markup::compliance_map:
  version: 1.0.0
  disa:
    useradd::shells:
      identifiers:
        - FOO
        - BAR
      notes: Nothing fun really
      value:
        - /bin/disa
  nist:
    useradd::shells:
      identifiers:
        - FOO2
        - BAR2
      notes: Nothing fun really
      value:
        - /bin/nist
                          EOF
  }
  let (:v3_hiera_yaml) { <<-EOM
---
:backends:
  - yaml
  - simp_compliance_enforcement
:yaml:
  :datadir: "/etc/puppetlabs/code/environments/%{environment}/hieradata"
:simp_compliance_enforcement:
  :datadir: "/etc/puppetlabs/code/environments/%{environment}/hieradata"
:hierarchy:
  - default
:logger: console
                         EOM
  }
  let (:v5_hiera_yaml) { <<-EOM
---
version: 5
hierarchy:
  - name: Compliance
    lookup_key: compliance_markup::enforcement
  - name: Common
    path: default.yaml
defaults:
  data_hash: yaml_data
  datadir: "/etc/puppetlabs/code/environments/production/hieradata"
                         EOM
  }

  hosts.each do |host|
    puppetver = SemanticPuppet::Version.parse(ENV.fetch('PUPPET_VERSION', '4.8.2'))
    requiredver = SemanticPuppet::Version.parse("4.9.0")
    if (puppetver > requiredver)
      versions = [ "v3", "v5" ]
    else
      versions = [ "v3" ]
    end
    versions.each do |version|
      context "with a #{version} hiera.yaml" do
        context 'with a single compliance map' do
          case version
          when "v3"
            let (:hiera_yaml)  { v3_hiera_yaml }
          when "v5"
            let (:hiera_yaml)  { v5_hiera_yaml }
          end
          # Using puppet_apply as a helper
          it 'should work with no errors' do
            set_profile_data_on(host, hiera_yaml, base_hieradata)
            apply_manifest_on(host, base_manifest, :catch_failures => true)
          end

          it 'should be idempotent' do
            apply_manifest_on(host, base_manifest, :catch_changes => true)
          end

          it 'should have /bin/sh in /etc/shells' do
            apply_manifest_on(host, base_manifest, :catch_failures => true)
            result = on(host, 'cat /etc/shells').output.strip
            expect(result).to match(%r(/bin/sh))
          end
          context 'when disa is higher priority' do
            it 'should have /bin/disa in /etc/shells' do
              apply_manifest_on(host, base_manifest, :catch_failures => true)
              result = on(host, 'cat /etc/shells').output.strip
              expect(result).to match(%r(/bin/disa))
            end
            it 'should not have /bin/nist in /etc/shells' do
              apply_manifest_on(host, base_manifest, :catch_failures => true)
              result = on(host, 'cat /etc/shells').output.strip
              expect(result).to_not match(%r(/bin/nistl))
            end
          end
          context 'when nist is higher priority' do
            it 'should have /bin/nist in /etc/shells' do
              set_profile_data_on(host, hiera_yaml, extra_hieradata)
              apply_manifest_on(host, base_manifest, :catch_failures => true)
              result = on(host, 'cat /etc/shells').output.strip
              expect(result).to match(%r(/bin/nist))
            end
            it 'should not have /bin/disa in /etc/shells' do
              set_profile_data_on(host, hiera_yaml, extra_hieradata)
              apply_manifest_on(host, base_manifest, :catch_failures => true)
              result = on(host, 'cat /etc/shells').output.strip
              expect(result).to_not match(%r(/bin/disa))
            end
          end
        end
      end
    end
  end
end

