#!/usr/bin/env ruby -S rspec

require 'spec_helper'
require 'semantic_puppet'
require 'puppet/pops/lookup/context'
require 'yaml'
require 'fileutils'

describe 'lookup' do
  # Generate a fake module with dummy data for lookup().
  let(:profile_yaml) do
    {
      'version' => '2.0.0',
      'profiles' => {
        '00_profile_test' => {
          'controls' => {
            '00_control1' => true,
          },
        },
        '00_profile_with_check_reference' => {
          'checks' => {
            '00_check2' => true,
          },
        },
      },
    }.to_yaml
  end

  let(:ces_yaml) do
    {
      'version' => '2.0.0',
      'ce' => {
        '00_ce1' => {
          'controls' => {
            '00_control1' => true,
          },
        },
      },
    }.to_yaml
  end

  let(:checks_yaml) do
    {
      'version' => '2.0.0',
      'checks' => {
        '00_check1' => {
          'type'     => 'puppet-class-parameter',
          'settings' => {
            'parameter' => 'test_module_00::test_param',
            'value'     => 'a string',
          },
          'ces' => [
            '00_ce1',
          ],
        },
        '00_check2' => {
          'type'     => 'puppet-class-parameter',
          'settings' => {
            'parameter' => 'test_module_00::test_param2',
            'value'     => 'another string',
          },
          'ces' => [
            '00_ce1',
          ],
        },
      },
    }.to_yaml
  end

  let(:fixtures) { File.expand_path('../../fixtures', __dir__) }

  let(:compliance_dir) { File.join(fixtures, 'modules', 'test_module_00', 'SIMP', 'compliance_profiles') }
  let(:compliance_files) { ['profile.yaml', 'ces.yaml', 'checks.yaml'].map { |f| File.join(compliance_dir, f) } }

  before(:each) do
    allow(Dir).to receive(:glob).and_call_original
    allow(Dir).to receive(:glob).with(%r{\bSIMP/compliance_profiles\b.*/\*\*/\*\.yaml$}, any_args) do |_, &block|
      compliance_files.each(&block)
    end

    allow(File).to receive(:read).and_call_original
    allow(File).to receive(:read).with(File.join(compliance_dir, 'profile.yaml'), any_args).and_return(profile_yaml)
    allow(File).to receive(:read).with(File.join(compliance_dir, 'ces.yaml'), any_args).and_return(ces_yaml)
    allow(File).to receive(:read).with(File.join(compliance_dir, 'checks.yaml'), any_args).and_return(checks_yaml)
  end

  on_supported_os.each do |os, os_facts|
    context "on #{os} with compliance_markup::enforcement and a non-existent profile" do
      let(:facts) do
        os_facts.merge('target_compliance_profile' => 'not_a_profile')
      end

      let(:hieradata) { 'compliance-engine' }

      it {
        is_expected.to run.with_params('test_module_00::test_param')
                          .and_raise_error(Puppet::DataBinding::LookupError, "Function lookup() did not find a value for the name 'test_module_00::test_param'")
      }
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

    context "on #{os} with compliance_markup::enforcement and a profile directly referencing a check" do
      let(:facts) do
        os_facts.merge('target_compliance_profile' => '00_profile_with_check_reference')
      end

      let(:hieradata) { 'compliance-engine' }

      # Test unconfined data.
      it {
        is_expected.to run.with_params('test_module_00::test_param')
                          .and_raise_error(Puppet::DataBinding::LookupError, "Function lookup() did not find a value for the name 'test_module_00::test_param'")
      }
      it { is_expected.to run.with_params('test_module_00::test_param2').and_return('another string') }
    end
  end
end
