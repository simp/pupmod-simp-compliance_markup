#!/usr/bin/env ruby -S rspec

require 'spec_helper'
require 'semantic_puppet'
require 'puppet/pops/lookup/context'
require 'yaml'
require 'fileutils'

SemanticPuppet::Version.parse(Puppet.version)
SemanticPuppet::Version.parse('4.10.0')

describe 'lookup' do
  # Generate a fake module with dummy data for lookup().
  profile_yaml = {
    'version' => '2.0.0',
    'profiles' => {
      '02_profile_test' => {
        'controls' => {
          '02_control1' => true,
        },
      },
    },
  }.to_yaml

  ces_yaml = {
    'version' => '2.0.0',
    'ce' => {
      '02_ce1' => {
        'controls' => {
          '02_control1' => true,
        },
      },
    },
  }.to_yaml

  checks_yaml = {
    'version' => '2.0.0',
    'checks'  => {
      '02_array check1' => {
        'type'     => 'puppet-class-parameter',
        'settings' => {
          'parameter' => 'test_module_02::array_param',
          'value'     => [
            'array value 1',
          ],
        },
        'ces' => [
          '02_ce1',
        ],
      },
      '02_array check2' => {
        'type'     => 'puppet-class-parameter',
        'settings' => {
          'parameter' => 'test_module_02::array_param',
          'value'     => [
            'array value 2',
          ],
        },
        'ces' => [
          '02_ce1',
        ],
      },
      '02_hash check1' => {
        'type'     => 'puppet-class-parameter',
        'settings' => {
          'parameter' => 'test_module_02::hash_param',
          'value'     => {
            'hash key 1' => 'hash value 1',
          },
        },
        'ces' => [
          '02_ce1',
        ],
      },
      '02_hash check2' => {
        'type'     => 'puppet-class-parameter',
        'settings' => {
          'parameter' => 'test_module_02::hash_param',
          'value'     => {
            'hash key 2' => 'hash value 2',
          },
        },
        'ces' => [
          '02_ce1',
        ],
      },
      '02_nested hash1' => {
        'type'     => 'puppet-class-parameter',
        'settings' => {
          'parameter' => 'test_module_02::nested_hash',
          'value'     => {
            'key' => {
              'key1' => 'value1',
            },
          },
        },
        'ces' => [
          '02_ce1',
        ],
      },
      '02_nested hash2' => {
        'type'     => 'puppet-class-parameter',
        'settings' => {
          'parameter' => 'test_module_02::nested_hash',
          'value'     => {
            'key' => {
              'key2' => 'value2',
            },
          },
        },
        'ces' => [
          '02_ce1',
        ],
      },
    },
  }.to_yaml

  fixtures = File.expand_path('../../fixtures', __dir__)

  compliance_dir = File.join(fixtures, 'modules', 'test_module_02', 'SIMP', 'compliance_profiles')
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
        os_facts.merge('target_compliance_profile' => '02_profile_test')
      end

      let(:hieradata) { 'compliance-engine' }

      # Test a simple array.
      it { is_expected.to run.with_params('test_module_02::array_param').and_return(['array value 1', 'array value 2']) }

      # Test a simple hash.
      it { is_expected.to run.with_params('test_module_02::hash_param').and_return({ 'hash key 1' => 'hash value 1', 'hash key 2' => 'hash value 2' }) }

      # Test a nested hash.
      it { is_expected.to run.with_params('test_module_02::nested_hash').and_return({ 'key' => { 'key1' => 'value1', 'key2' => 'value2' } }) }
    end
  end
end
