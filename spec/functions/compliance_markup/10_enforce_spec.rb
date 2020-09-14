require 'spec_helper'

def write_hieradata(policy_order)
  data = {
    'compliance_markup::enforcement'    => policy_order,
    'compliance_markup::compliance_map' => {
      'version' => '2.0.0',
      'checks'  => {
        'oval:com.puppet.test.disa.useradd_shells' => {
          'type'        => 'puppet-class-parameter',
          'controls'    => {
            'disa_stig' => true,
          },
          'identifiers' => {
            'FOO2' => ['FOO2'],
            'BAR2' => ['BAR2']
          },
          'settings'    => {
            'parameter' => 'useradd::shells',
            'value'     => ['/bin/disa']
          }
        },
        'oval:com.puppet.test.nist.useradd_shells' => {
          'type'        => 'puppet-class-parameter',
          'controls'    => {
            'nist_800_53:rev4' => true
          },
          'identifiers' => {
            'FOO2' => ['FOO2'],
            'BAR2' => ['BAR2']
          },
          'settings'    => {
            'parameter' => 'useradd::shells',
            'value'     => ['/bin/nist']
          }
        }
      }
    }
  }

  fixtures = File.expand_path('../../fixtures', __dir__)

  File.open(File.join(fixtures, 'hieradata', '10_enforce_spec.yaml'), 'w') do |fh|
    fh.puts data.to_yaml
  end
end

describe 'lookup' do
  on_supported_os.each do |os, os_facts|
    context "on #{os}" do
      context 'with a single compliance map' do
        let(:hieradata) { '10_enforce_spec' }
        let(:policy_order) { ['disa_stig'] }

        before(:each) do
          write_hieradata(policy_order)
        end

        it 'returns /bin/disa' do
          result = subject.execute('useradd::shells')
          expect(result).to be_instance_of(Array)
          expect(result).to include('/bin/disa')
        end
      end

      context 'when disa is higher priority' do
        let(:hieradata) { '10_enforce_spec' }
        let(:policy_order) { ['disa_stig', 'nist_800_53:rev4'] }

        before(:each) do
          write_hieradata(policy_order)
        end

        it 'returns /bin/disa and /bin/nist' do
          result = subject.execute('useradd::shells')
          expect(result).to be_instance_of(Array)
          expect(result).to include('/bin/disa')
          expect(result).to include('/bin/nist')
        end
      end
    end
  end
end
