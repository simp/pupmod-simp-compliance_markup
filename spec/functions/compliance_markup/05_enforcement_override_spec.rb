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
      'version'  => '2.0.0',
      'profiles' => {
        'profile_test1' => {
          'ces' => {
            '05_profile_test1' => true,
            '05_profile_test2' => true,
          },
        },
      },
    }.to_yaml
  end

  let(:ces_yaml) do
    {
      'version' => '2.0.0',
      'ce'      => {
        '05_profile_test1' => {},
        '05_profile_test2' => {},
      },
    }.to_yaml
  end

  let(:checks_yaml) do
    {
      'version' => '2.0.0',
      'checks'  => {
        '05_hash check1'   => {
          'type'     => 'puppet-class-parameter',
          'settings' => {
            'parameter' => 'test_module_05::hash_param',
            'value'     => {
              'hash key 1' => 'hash value 1',
            },
          },
          'ces' => [
            '05_profile_test1',
          ],
        },
        '05_hash check2' => {
          'type'     => 'puppet-class-parameter',
          'settings' => {
            'parameter' => 'test_module_05::hash_param',
            'value'     => {
              'hash key 2' => 'hash value 2',
            },
          },
          'ces' => [
            '05_profile_test2',
          ],
        },
      },
    }.to_yaml
  end

  let(:fixtures) { File.expand_path('../../fixtures', __dir__) }

  let(:compliance_dir) { File.join(fixtures, 'modules', 'test_module_05', 'SIMP', 'compliance_profiles') }
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
    let(:facts) { os_facts }

    context "on #{os} with compliance data in modules" do
      before(:each) do
        File.open(File.join(fixtures, 'hieradata', 'profile-merging.yaml'), 'w') do |fh|
          test_hiera = { 'compliance_markup::enforcement' => ['profile_test1'] }.to_yaml
          fh.puts test_hiera
        end
      end

      let(:hieradata) { 'profile-merging' }

      # Test a simple hash.
      it { is_expected.to run.with_params('test_module_05::hash_param').and_return({ 'hash key 1' => 'hash value 1', 'hash key 2' => 'hash value 2' }) }
    end

    context "on #{os} with compliance_markup::compliance_map override" do
      before(:each) do
        File.open(File.join(fixtures, 'hieradata', 'profile-merging.yaml'), 'w') do |fh|
          test_hiera = {
            'compliance_markup::enforcement'    => ['profile_test1'],
            'compliance_markup::compliance_map' => {
              'version'  => '2.0.0',
              'profiles' => {
                'profile_test1' => {
                  'ces' => {
                    '05_profile_test2' => false,
                  },
                },
              },
            },
          }.to_yaml
          fh.puts test_hiera
        end
      end

      let(:hieradata) { 'profile-merging' }

      # Test a simple hash.
      it { is_expected.to run.with_params('test_module_05::hash_param').and_return({ 'hash key 1' => 'hash value 1' }) }
    end
  end
end
