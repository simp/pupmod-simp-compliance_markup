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
    'version' => '2.0.0',
    'profiles' => {
      '00_profile_test' => {
        'controls' => {
          '00_control1' => true,
        },
      },
    },
  }.to_yaml

  ces_yaml = {
    'version' => '2.0.0',
    'ce' => {
      '00_ce1' => {
        'controls' => {
          '00_control1' => true,
        },
      },
    },
  }.to_yaml

  checks_yaml = {
    'version' => '2.0.0',
    'checks' => {
      '00_check1' => {
        'type'     => 'puppet-class-parameter',
        'settings' => {
          'parameter' => 'test_module_00::test_param',
          'value'     => 'a string',
        },
        'ces'      => [
          '00_ce1',
        ],
      },
      '00_check2' => {
        'type'     => 'puppet-class-parameter',
        'settings' => {
          'parameter' => 'test_module_00::test_param2',
          'value'     => 'another string',
        },
        'ces'      => [
          '00_ce1',
        ],
      },
    },
  }.to_yaml

  fixtures = File.expand_path('../../fixtures', __dir__)

  compliance_dir = File.join(fixtures, 'modules', 'test_module_00', 'SIMP', 'compliance_profiles')
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

      it { is_expected.to run.with_params('test_module_00::test_param').and_raise_error(Puppet::DataBinding::LookupError, "Function lookup() did not find a value for the name 'test_module_00::test_param'") }
    end

    context "on #{os} with compliance_markup::enforcement and an existing profile" do
      let(:facts) do
        os_facts.merge('target_compliance_profile' => '00_profile_test')
      end

      let(:hieradata) { 'compliance-engine' }

      # Test unconfined data.
      it { is_expected.to run.with_params('test_module_00::test_param').and_return('a string') }
      it { is_expected.to run.with_params('test_module_00::test_param2').and_return('another string') }
    end
  end
end
