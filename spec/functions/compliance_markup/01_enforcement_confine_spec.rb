#!/usr/bin/env ruby -S rspec

require 'spec_helper'
require 'semantic_puppet'
require 'puppet/pops/lookup/context'
require 'yaml'
require 'fileutils'

puppetver = SemanticPuppet::Version.parse(Puppet.version)
requiredver = SemanticPuppet::Version.parse("4.10.0")

describe 'lookup' do
  # Generate a fake module with dummy data for lookup().
  profile_yaml = {
    'version'  => '2.0.0',
    'profiles' => {
      '01_profile_test' => {
        'controls' => {
          '01_control1'   => true,
          '01_os_control' => true,
        },
      },
    },
  }.to_yaml

  ces_yaml = {
    'version' => '2.0.0',
    'ce'      => {
      '01_ce1' => {
        'controls' => {
          '01_control1' => true,
        },
      },
      '01_ce2' => {
        'controls' => {
          '01_os_control' => true,
        },
      },
      '01_ce3' => {
        'controls' => {
          '01_control1' => true,
        },
        'confine'  => {
          'module_name'    => 'simp-compliance_markup',
          'module_version' => '< 3.1.0',
        },
      },
    },
  }.to_yaml

  checks_yaml = {
    'version' => '2.0.0',
    'checks'  => {
      '01_el_check'       => {
        'type'     => 'puppet-class-parameter',
        'settings' => {
          'parameter' => 'test_module_01::is_el',
          'value'     => true,
        },
        'ces'      => [
          '01_ce2',
        ],
        'confine'  => {
          'os.family' => 'RedHat',
        },
      },
      '01_el7_check'      => {
        'type'     => 'puppet-class-parameter',
        'settings' => {
          'parameter' => 'test_module_01::el_version',
          'value'     => '7',
        },
        'ces'      => [
          '01_ce2',
        ],
        'confine'  => {
          'os.name'          => [
            'RedHat',
            'CentOS',
          ],
          'os.release.major' => '7',
        },
      },
      '01_confine_in_ces' => {
        'type'     => 'puppet-class-parameter',
        'settings' => {
          'parameter' => 'test_module_01::fixed_confines',
          'value'     => false,
        },
        'ces'      => [
          '01_ce3',
        ],
      },
    },
  }.to_yaml

  fixtures = File.expand_path('../../fixtures', __dir__)

  compliance_dir = File.join(fixtures, 'modules', 'test_module_01', 'SIMP', 'compliance_profiles')
  FileUtils.mkdir_p(compliance_dir)

  File.open(File.join(compliance_dir, 'profile.yaml'), 'w') do |fh|
    fh.puts profile_yaml
  end

  File.open(File.join(compliance_dir, 'ces.yaml'), 'w') do |fh|
    fh.puts ces_yaml
  end

  File.open(File.join(compliance_dir, 'checks.yaml'), 'w') do |fh|
    fh.puts checks_yaml
  end

  on_supported_os.each do |os, os_facts|
    context "on #{os} with compliance_markup::enforcement and an existing profile" do
      let(:facts) do
        os_facts.merge('target_compliance_profile' => '01_profile_test')
      end

      let(:hieradata) { 'compliance-engine' }

      # Test for confine on a single fact in checks.
      if os_facts[:osfamily] == 'RedHat'
        it { is_expected.to run.with_params('test_module_01::is_el').and_return(true) }
      else
        it { is_expected.to run.with_params('test_module_01::is_el').and_raise_error(Puppet::DataBinding::LookupError, "Function lookup() did not find a value for the name 'test_module_01::is_el'") }
      end

      # Test for confine on multiple facts and an array of facts in checks.
      if (os_facts[:os][:name] == 'RedHat' || os_facts[:os][:name] == 'CentOS') && os_facts[:operatingsystemmajrelease] == '7'
        it { is_expected.to run.with_params('test_module_01::el_version').and_return('7') }
      else
        it { is_expected.to run.with_params('test_module_01::el_version').and_raise_error(Puppet::DataBinding::LookupError, "Function lookup() did not find a value for the name 'test_module_01::el_version'") }
      end

      # Test for confine on module name & module version in ce.
      it { is_expected.to run.with_params('test_module_01::fixed_confines').and_raise_error(Puppet::DataBinding::LookupError, "Function lookup() did not find a value for the name 'test_module_01::fixed_confines'") }
    end
  end
end
