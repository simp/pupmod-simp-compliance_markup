#!/usr/bin/env ruby -S rspec

require 'spec_helper'
require 'semantic_puppet'
require 'puppet/pops/lookup/context'
require 'yaml'
require 'fileutils'
require 'pry'

puppetver = SemanticPuppet::Version.parse(Puppet.version)
requiredver = SemanticPuppet::Version.parse("4.10.0")

describe 'lookup' do
  # Generate a fake module with dummy data for lookup().
  profile_yaml = {
    'version' => '2.0.0',
    'profiles' => {
      'profile_test' => {
        'controls' => {
          'control1' => true,
          'os_control' => true,
        },
        # Future
        # 'confine' => {
        #   # Test for module name
        #   # Test for module version
        #   # Test for single fact
        #   # Test for multiple facts
        #   # Test for array of facts
        # },
      },
    },
  }.to_yaml

  ces_yaml = {
    'version' => '2.0.0',
    'ce' => {
      'ce1' => {
        'controls' => {
          'control1' => true,
        },
      },
      'ce2' => {
        'controls' => {
          'os_control' => true,
        },
      },
      'ce3' => {
        'controls' => {
          'control1' => true,
        },
        'confine' => {
          'module_name' => 'simp-compliance_markup',
          'module_version' => '< 3.1.0',
        },
      },
    },
  }.to_yaml

  checks_yaml = {
    'version' => '2.0.0',
    'checks' => {
      'check1' => {
        'type' => 'puppet-class-parameter',
        'settings' => {
          'parameter' => 'test_module::test_param',
          'value' => 'a string',
        },
        'ces' => [
          'ce1',
        ],
      },
      'check2' => {
        'type' => 'puppet-class-parameter',
        'settings' => {
          'parameter' => 'test_module::test_param2',
          'value' => 'another string',
        },
        'ces' => [
          'ce1',
        ],
      },
      'el_check' => {
        'type' => 'puppet-class-parameter',
        'settings' => {
          'parameter' => 'test_module::is_el',
          'value' => true,
        },
        'ces' => [
          'ce2',
        ],
        'confine' => {
          'os.family' => 'RedHat',
        },
      },
      'el7_check' => {
        'type' => 'puppet-class-parameter',
        'settings' => {
          'parameter' => 'test_module::el_version',
          'value' => '7',
        },
        'ces' => [
          'ce2',
        ],
        'confine' => {
          'os.name' => [
            'RedHat',
            'CentOS',
          ],
          'os.release.major' => '7',
        },
      },
      'confine_in_ces' => {
        'type' => 'puppet-class-parameter',
        'settings' => {
          'parameter' => 'test_module::fixed_confines',
          'value' => false,
        },
        'ces' => [
          'ce3',
        ],
      },
    },
  }.to_yaml

  fixtures = File.expand_path('../../fixtures', __dir__)

  compliance_dir = File.join(fixtures, 'modules', 'test_module', 'SIMP', 'compliance_profiles')
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
    context "on #{os} with compliance_markup::enforcement and a non-existent profile" do
      let(:facts) do
        os_facts.merge('target_compliance_profile' => 'not_a_profile')
      end

      let(:hieradata) { 'compliance-engine' }

      it { is_expected.to run.with_params('test_module::test_param').and_raise_error(Puppet::DataBinding::LookupError, "Function lookup() did not find a value for the name 'test_module::test_param'") }
    end

    context "on #{os} with compliance_markup::enforcement and an existing profile" do
      let(:facts) do
        os_facts.merge('target_compliance_profile' => 'profile_test')
      end

      let(:hieradata) { 'compliance-engine' }

      # Test unconfined data.
      it { is_expected.to run.with_params('test_module::test_param').and_return('a string') }
      it { is_expected.to run.with_params('test_module::test_param2').and_return('another string') }

      # Test for confine on a single fact in checks.
      if os_facts[:osfamily] == 'RedHat'
        it { is_expected.to run.with_params('test_module::is_el').and_return(true) }
      else
        it { is_expected.to run.with_params('test_module::is_el').and_raise_error(Puppet::DataBinding::LookupError, "Function lookup() did not find a value for the name 'test_module::is_el'") }
      end

      # Test for confine on multiple facts and an array of facts in checks.
      if (os_facts[:os][:name] == 'RedHat' || os_facts[:os][:name] == 'CentOS') && os_facts[:operatingsystemmajrelease] == '7'
        it { is_expected.to run.with_params('test_module::el_version').and_return('7') }
      else
        it { is_expected.to run.with_params('test_module::el_version').and_raise_error(Puppet::DataBinding::LookupError, "Function lookup() did not find a value for the name 'test_module::el_version'") }
      end

      # Test for confine on module name & module version in ce.
      it { is_expected.to run.with_params('test_module::fixed_confines').and_raise_error(Puppet::DataBinding::LookupError, "Function lookup() did not find a value for the name 'test_module::fixed_confines'") }
    end
  end
end
