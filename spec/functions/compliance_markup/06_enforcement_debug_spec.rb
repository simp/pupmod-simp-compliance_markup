#!/usr/bin/env ruby -S rspec

require 'spec_helper'
require 'semantic_puppet'
require 'puppet/pops/lookup/context'
require 'yaml'
require 'fileutils'

describe 'lookup' do
  # Generate a fake module with dummy data for lookup().
  let(:profile) do
    {
      'version' => '2.0.0',
      'profiles' => {
        '06_profile_test' => {
          'controls' => {
            '06_control1' => true,
          },
        },
      },
    }
  end

  let(:ces) do
    {
      'version' => '2.0.0',
      'ce' => {
        '06_ce1' => {
          'controls' => {
            '06_control1' => true,
          },
        },
      },
    }
  end

  let(:checks) do
    {
      'version' => '2.0.0',
      'checks' => {
        '06_check1' => {
          'type'     => 'puppet-class-parameter',
          'settings' => {
            'parameter' => 'test_module_06::test_param',
            'value'     => 'a string',
          },
          'ces' => [
            '06_ce1',
          ],
        },
        '06_check2' => {
          'type'     => 'puppet-class-parameter',
          'settings' => {
            'parameter' => 'test_module_06::test_param2',
            'value'     => 'another string',
          },
          'ces' => [
            '06_ce1',
          ],
        },
      },
    }
  end

  let(:fixtures) { File.expand_path('../../fixtures', __dir__) }

  let(:compliance_dir) { File.join(fixtures, 'modules', 'test_module_06', 'SIMP', 'compliance_profiles') }
  let(:compliance_files) { ['profile.yaml', 'ces.yaml', 'checks.yaml'].map { |f| File.join(compliance_dir, f) } }

  before(:each) do
    allow(Dir).to receive(:glob).and_call_original
    allow(Dir).to receive(:glob).with(%r{\bSIMP/compliance_profiles\b.*/\*\*/\*\.yaml$}, any_args) do |_, &block|
      compliance_files.each(&block)
    end

    allow(File).to receive(:read).and_call_original
    allow(File).to receive(:read).with(File.join(compliance_dir, 'profile.yaml'), any_args).and_return(profile.to_yaml)
    allow(File).to receive(:read).with(File.join(compliance_dir, 'ces.yaml'), any_args).and_return(ces.to_yaml)
    allow(File).to receive(:read).with(File.join(compliance_dir, 'checks.yaml'), any_args).and_return(checks.to_yaml)
  end

  on_supported_os.each do |os, os_facts|
    context "on #{os} compliance_markup::debug values" do
      let(:lookup) { subject }
      let(:facts) do
        os_facts.merge('target_compliance_profile' => '06_profile_test')
      end

      let(:hieradata) { 'compliance-engine' }

      it do
        result = lookup.execute('compliance_markup::debug::hiera_backend_compile_time')
        expect(result).to be_a(Float)
        expect(result).to be > 0
      end

      it do
        result = lookup.execute('compliance_markup::debug::dump')
        expect(result).to be_a(Hash)
        expect(result['test_module_06::test_param']).to eq('a string')
        expect(result['test_module_06::test_param2']).to eq('another string')
        expect(result.keys).to eq([
                                    'test_module_06::test_param',
                                    'test_module_06::test_param2',
                                    'compliance_markup::debug::hiera_backend_compile_time',
                                  ])
      end

      it do
        result = lookup.execute('compliance_markup::debug::profiles')
        expect(result).to be_a(Array)
        expect(result).to include('06_profile_test')
      end

      it do
        result = lookup.execute('compliance_markup::debug::compliance_data')
        expect(result).to be_a(Hash)
        expect(result.keys).to eq(['version', 'profiles', 'ce', 'checks'])
        expect(result['profiles']).to include(profile['profiles'])
        expect(result['ce']).to include(ces['ce'])
        expect(result['checks']).to include(checks['checks'])
      end
    end
  end
end
