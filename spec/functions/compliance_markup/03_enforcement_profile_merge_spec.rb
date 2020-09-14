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
      'profile_test1' => {
        'ces' => {
          '03_profile_test1' => true,
        },
      },
      'profile_test2' => {
        'ces' => {
          '03_profile_test2' => true,
        },
      },
    },
  }.to_yaml

  ces_yaml = {
    'version' => '2.0.0',
    'ce'      => {
      '03_profile_test1' => {},
      '03_profile_test2' => {},
    },
  }.to_yaml

  checks_yaml = {
    'version' => '2.0.0',
    'checks'  => {
      '03_string check1' => {
        'type'     => 'puppet-class-parameter',
        'settings' => {
          'parameter' => 'test_module_03::string_param',
          'value'     => 'string value 1',
        },
        'ces'      => [
          '03_profile_test1',
        ],
      },
      '03_string check2' => {
        'type'     => 'puppet-class-parameter',
        'settings' => {
          'parameter' => 'test_module_03::string_param',
          'value'     => 'string value 2',
        },
        'ces'      => [
          '03_profile_test2',
        ],
      },
      '03_array check1'  => {
        'type'     => 'puppet-class-parameter',
        'settings' => {
          'parameter' => 'test_module_03::array_param',
          'value'     => [
            'array value 1',
          ],
        },
        'ces'      => [
          '03_profile_test1',
        ],
      },
      '03_array check2'  => {
        'type'     => 'puppet-class-parameter',
        'settings' => {
          'parameter' => 'test_module_03::array_param',
          'value'     => [
            'array value 2',
          ],
        },
        'ces'      => [
          '03_profile_test2',
        ],
      },
      '03_hash check1'   => {
        'type'     => 'puppet-class-parameter',
        'settings' => {
          'parameter' => 'test_module_03::hash_param',
          'value'     => {
            'hash key 1' => 'hash value 1',
          },
        },
        'ces'      => [
          '03_profile_test1',
        ],
      },
      '03_hash check2'   => {
        'type'     => 'puppet-class-parameter',
        'settings' => {
          'parameter' => 'test_module_03::hash_param',
          'value'     => {
            'hash key 2' => 'hash value 2',
          },
        },
        'ces'      => [
          '03_profile_test2',
        ],
      },
      '03_nested hash1'  => {
        'type'     => 'puppet-class-parameter',
        'settings' => {
          'parameter' => 'test_module_03::nested_hash',
          'value'     => {
            'key' => {
              'key1' => 'value1',
            },
          },
        },
        'ces'      => [
          '03_profile_test1',
        ],
      },
      '03_nested hash2'  => {
        'type'     => 'puppet-class-parameter',
        'settings' => {
          'parameter' => 'test_module_03::nested_hash',
          'value'     => {
            'key' => {
              'key1' => 'value2',
              'key2' => 'value2',
            },
          },
        },
        'ces'      => [
          '03_profile_test2',
        ],
      },
    },
  }.to_yaml

  fixtures = File.expand_path('../../fixtures', __dir__)

  compliance_dir = File.join(fixtures, 'modules', 'test_module_03', 'SIMP', 'compliance_profiles')
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
    context "on #{os} with compliance_markup::enforcement merging profiles" do
      before(:all) do
        File.open(File.join(fixtures, 'hieradata', 'profile-merging.yaml'), 'w') do |fh|
          test_hiera = {'compliance_markup::enforcement' => ['profile_test1', 'profile_test2']}.to_yaml
          fh.puts test_hiera
        end
      end

      let(:hieradata) { 'profile-merging' }

      # Test a string.
      it { is_expected.to run.with_params('test_module_03::string_param').and_return('string value 1') }

      # Test a simple array.
      it { is_expected.to run.with_params('test_module_03::array_param').and_return(['array value 2', 'array value 1']) }

      # Test a simple hash.
      it { is_expected.to run.with_params('test_module_03::hash_param').and_return({'hash key 1' => 'hash value 1', 'hash key 2' => 'hash value 2'}) }

      # Test a nested hash.
      it { is_expected.to run.with_params('test_module_03::nested_hash').and_return({'key' => { 'key1' => 'value1', 'key2' => 'value2'}}) }
    end

    context "on #{os} with compliance_markup::enforcement merging profiles in reverse order" do
      before(:all) do
        File.open(File.join(fixtures, 'hieradata', 'profile-merging.yaml'), 'w') do |fh|
          test_hiera = {'compliance_markup::enforcement' => ['profile_test2', 'profile_test1']}.to_yaml
          fh.puts test_hiera
        end
      end

      let(:hieradata) { 'profile-merging' }

      # Test a string.
      it { is_expected.to run.with_params('test_module_03::string_param').and_return('string value 2') }

      # Test a simple array.
      it { is_expected.to run.with_params('test_module_03::array_param').and_return(['array value 1', 'array value 2']) }

      # Test a simple hash.
      it { is_expected.to run.with_params('test_module_03::hash_param').and_return({'hash key 2' => 'hash value 2', 'hash key 1' => 'hash value 1'}) }

      # Test a nested hash.
      it { is_expected.to run.with_params('test_module_03::nested_hash').and_return({'key' => { 'key1' => 'value2', 'key2' => 'value2'}}) }
    end
  end
end
