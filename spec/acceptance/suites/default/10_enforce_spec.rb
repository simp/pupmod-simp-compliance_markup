require 'spec_helper_acceptance'
require 'semantic_puppet'
test_name 'compliance_markup class enforcement'

describe 'compliance_markup class enforcement' do
  let(:manifest) do
    <<-EOS
      include 'useradd'
    EOS
  end

  let(:hieradata) do
    {
      'compliance_markup::enforcement' => policy_order,
   'compliance_markup::compliance_map' => {
     'version' => '2.0.0',
     'checks' => {
       'oval:com.puppet.test.disa.useradd_shells' => {
         'type'     => 'puppet-class-parameter',
         'controls' => {
           'disa_stig' => true,
         },
         'identifiers' => {
           'FOO2' => ['FOO2'],
           'BAR2' => ['BAR2']
         },
         'settings' => {
           'parameter' => 'useradd::shells',
           'value'     => ['/bin/disa']
         }
       },
       'oval:com.puppet.test.nist.useradd_shells' => {
         'type'     => 'puppet-class-parameter',
         'controls' => {
           'nist_800_53:rev4' => true
         },
         'identifiers' => {
           'FOO2' => ['FOO2'],
           'BAR2' => ['BAR2']
         },
         'settings' => {
           'parameter' => 'useradd::shells',
           'value'     => ['/bin/nist']
         }
       }
     }
   }
    }
  end

  let(:hiera_yaml) { File.read(File.join(__dir__, 'files', 'hiera_v5.yaml')) }

  hosts.each do |host|
    context "on #{host.name}" do
      context 'with a single compliance map' do
        let(:policy_order) { ['disa_stig'] }

        it 'works with no errors' do
          create_remote_file(host, host.puppet['hiera_config'], hiera_yaml)
          set_hieradata_on(host, hieradata)
          apply_manifest_on(host, manifest, catch_failures: true)
        end

        it 'is idempotent' do
          apply_manifest_on(host, manifest, catch_changes: true)
        end

        it 'has /bin/sh in /etc/shells' do
          apply_manifest_on(host, manifest, catch_failures: true)
          result = on(host, 'cat /etc/shells').output.strip
          expect(result).to match(%r{/bin/sh})
        end

        context 'when disa is higher priority' do
          let(:policy_order) { ['disa_stig', 'nist_800_53:rev4'] }

          it 'has /bin/disa in /etc/shells' do
            create_remote_file(host, host.puppet['hiera_config'], hiera_yaml)

            set_hieradata_on(host, hieradata)

            apply_manifest_on(host, manifest, catch_failures: true)

            result = on(host, 'cat /etc/shells').output.strip
            expect(result).to match(%r{/bin/disa})
            expect(result).to match(%r{/bin/nist})
          end
        end
      end
    end
  end
end
