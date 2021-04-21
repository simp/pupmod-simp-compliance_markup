#!/usr/bin/env ruby -S rspec

require 'spec_helper'
require 'semantic_puppet'
require 'puppet/pops/lookup/context'
require 'yaml'
require 'fileutils'

describe 'lookup' do
  # Generate a fake module with dummy data for lookup().
  profile_yaml = {
    'version' => '2.0.0',
    'profiles' => {
      '06_profile_test' => {
        'controls' => {
          '06_control1' => true,
        },
      },
    },
  }.to_yaml

  ces_yaml = {
    'version' => '2.0.0',
    'ce' => {
      '06_ce1' => {
        'controls' => {
          '06_control1' => true,
        },
      },
    },
  }.to_yaml

  checks_yaml = {
    'version' => '2.0.0',
    'checks' => {
      '06_check1' => {
        'type'     => 'puppet-class-parameter',
        'settings' => {
          'parameter' => 'test_module_06::test_param',
          'value'     => 'a string',
        },
        'ces'      => [
          '06_ce1',
        ],
      },
      '06_check2' => {
        'type'     => 'puppet-class-parameter',
        'settings' => {
          'parameter' => 'test_module_06::test_param2',
          'value'     => 'another string',
        },
        'ces'      => [
          '06_ce1',
        ],
      },
    },
  }.to_yaml

  fixtures = File.expand_path('../../fixtures', __dir__)

  compliance_dir = File.join(fixtures, 'modules', 'test_module_06', 'SIMP', 'compliance_profiles')
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
    context "on #{os} compliance_markup::debug values" do
      let(:facts) do
        os_facts.merge('target_compliance_profile' => '06_profile_test')
      end

      let(:hieradata) { 'compliance-engine' }

      it do
        result = subject.execute('compliance_markup::debug::hiera_backend_compile_time')
        expect(result).to be_a(Float)
        expect(result).to be > 0
      end

      it do
        result = subject.execute('compliance_markup::debug::dump')
        expect(result).to be_a(Hash)
        expect(result['test_module_06::test_param']).to eq('a string')
        expect(result['test_module_06::test_param2']).to eq('another string')
        expect(result.keys).to eq([
          'test_module_06::test_param',
          'test_module_06::test_param2',
          'compliance_markup::debug::hiera_backend_compile_time',
        ])
      end
    end
  end
end
