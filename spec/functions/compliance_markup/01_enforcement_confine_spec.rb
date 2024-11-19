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
        '01_profile_test' => {
          'controls' => {
            '01_control1'   => true,
            '01_os_control' => true,
          },
        },
      },
    }.to_yaml
  end

  let(:ces_yaml) do
    {
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
          'confine' => {
            'module_name'    => 'simp-compliance_markup',
            'module_version' => '< 3.1.0',
          },
        },
      },
    }.to_yaml
  end

  let(:checks_yaml) do
    {
      'version' => '2.0.0',
      'checks'  => {
        '01_el_check' => {
          'type'     => 'puppet-class-parameter',
          'settings' => {
            'parameter' => 'test_module_01::is_el',
            'value'     => true,
          },
          'ces' => [
            '01_ce2',
          ],
          'confine' => {
            'os.family' => 'RedHat',
          },
        },
        '01_el_negative_check' => {
          'type'     => 'puppet-class-parameter',
          'settings' => {
            'parameter' => 'test_module_01::is_not_el',
            'value'     => true,
          },
          'ces' => [
            '01_ce2',
          ],
          'confine' => {
            'os.family' => '!RedHat',
          },
        },
        '01_disabled_check' => {
          'type'     => 'puppet-class-parameter',
          'settings' => {
            'parameter' => 'test_module_01::is_disabled',
            'value'     => true,
          },
          'ces' => [
            '01_ce2',
          ],
          'remediation' => {
            'disabled' => [
              { 'reason' => 'This is the reason this check is disabled.' },
            ]
          },
        },
        '01_level_21_check' => {
          'type'     => 'puppet-class-parameter',
          'settings' => {
            'parameter' => 'test_module_01::is_level_21',
            'value'     => true,
          },
          'ces' => [
            '01_ce2',
          ],
          'remediation' => {
            'risk' => [
              { 'level' => 21 },
            ]
          },
        },
        '01_level_41_check' => {
          'type'     => 'puppet-class-parameter',
          'settings' => {
            'parameter' => 'test_module_01::is_level_41',
            'value'     => true,
          },
          'ces' => [
            '01_ce2',
          ],
          'remediation' => {
            'risk' => [
              { 'level' => 41, 'reason' => 'this is the reason for level 41' },
            ]
          },
        },
        '01_level_61_check' => {
          'type'     => 'puppet-class-parameter',
          'settings' => {
            'parameter' => 'test_module_01::is_level_61',
            'value'     => true,
          },
          'ces' => [
            '01_ce2',
          ],
          'remediation' => {
            'risk' => [
              { 'level' => 61, 'reason' => 'this is the reason for level 61' },
            ]
          },
        },
        '01_level_81_check' => {
          'type'     => 'puppet-class-parameter',
          'settings' => {
            'parameter' => 'test_module_01::is_level_81',
            'value'     => true,
          },
          'ces' => [
            '01_ce2',
          ],
          'remediation' => {
            'risk' => [
              { 'level' => 81, 'reason' => 'this is the reason for level 81' },
            ]
          },
        },
        '01_el7_check' => {
          'type'     => 'puppet-class-parameter',
          'settings' => {
            'parameter' => 'test_module_01::el_version',
            'value'     => '7',
          },
          'ces' => [
            '01_ce2',
          ],
          'confine' => {
            'os.name' => [
              'RedHat',
              'CentOS',
            ],
            'os.release.major' => '7',
          },
        },
        '01_el7_negative_check' => {
          'type'     => 'puppet-class-parameter',
          'settings' => {
            'parameter' => 'test_module_01::not_el_version',
            'value'     => '7',
          },
          'ces' => [
            '01_ce2',
          ],
          'confine' => {
            'os.name' => [
              '!RedHat',
            ],
            'os.release.major' => '7',
          },
        },
        '01_el7_negative_mixed_check' => {
          'type'     => 'puppet-class-parameter',
          'settings' => {
            'parameter' => 'test_module_01::not_el_centos_version',
            'value'     => '7',
          },
          'ces' => [
            '01_ce2',
          ],
          'confine' => {
            'os.name' => [
              '!RedHat',
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
          'ces' => [
            '01_ce3',
          ],
        },
      },
    }.to_yaml
  end

  let(:fixtures) { File.expand_path('../../fixtures', __dir__) }

  let(:compliance_dir) { File.join(fixtures, 'modules', 'test_module_01', 'SIMP', 'compliance_profiles') }
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
    context "on #{os} with compliance_markup::enforcement and an existing profile" do
      let(:facts) do
        os_facts.merge('target_compliance_profile' => '01_profile_test')
      end

      let(:hieradata) { 'compliance-engine' }

      # Test for confine on a single fact in checks.
      if os_facts[:os][:family] == 'RedHat'
        it { is_expected.to run.with_params('test_module_01::is_el').and_return(true) }
      else
        it { is_expected.to run.with_params('test_module_01::is_el').and_raise_error(Puppet::DataBinding::LookupError, "Function lookup() did not find a value for the name 'test_module_01::is_el'") }
      end

      # Test for confine on a single fact in checks.
      if os_facts[:os][:family] != 'RedHat'
        it { is_expected.to run.with_params('test_module_01::is_not_el').and_return(true) }
      else
        it do
          is_expected.to run.with_params('test_module_01::is_not_el')
                            .and_raise_error(Puppet::DataBinding::LookupError, "Function lookup() did not find a value for the name 'test_module_01::is_not_el'")
        end
      end

      # Test for confine on multiple facts and an array of facts in checks.
      if (os_facts[:os][:name] == 'RedHat' || os_facts[:os][:name] == 'CentOS') && os_facts[:os][:release][:major] == '7'
        it { is_expected.to run.with_params('test_module_01::el_version').and_return('7') }
      else
        it do
          is_expected.to run.with_params('test_module_01::el_version')
                            .and_raise_error(Puppet::DataBinding::LookupError, "Function lookup() did not find a value for the name 'test_module_01::el_version'")
        end
      end

      # Test for confine on multiple facts and a negative fact match.
      if (os_facts[:os][:name] != 'RedHat') && os_facts[:os][:release][:major] == '7'
        it { is_expected.to run.with_params('test_module_01::not_el_version').and_return('7') }
      else
        it do
          is_expected.to run.with_params('test_module_01::not_el_version')
                            .and_raise_error(Puppet::DataBinding::LookupError, "Function lookup() did not find a value for the name 'test_module_01::not_el_version'")
        end
      end

      # Test for confine on multiple facts and a negative fact match mixed with a positive one.
      # TODO: This does not currently work as one might expect. This will still positively match OracleLinux even though
      # we ask for OS names that aren't RedHat but are CentOS. The array we're confining can only do an OR operation rather
      # than an AND with a negative lookup.
      if (os_facts[:os][:name] != 'RedHat') && (os_facts[:os][:name] == 'CentOS') && os_facts[:os][:release][:major] == '7'
        it { is_expected.to run.with_params('test_module_01::not_el_centos_version').and_return('7') } # FIXME: # rubocop:disable RSpec/RepeatedExample
      elsif (os_facts[:os][:name] != 'RedHat') && (os_facts[:os][:name] != 'CentOS') && os_facts[:os][:release][:major] == '7'
        it { is_expected.to run.with_params('test_module_01::not_el_centos_version').and_return('7') } # FIXME: # rubocop:disable RSpec/RepeatedExample
      else
        it do
          is_expected.to run.with_params('test_module_01::not_el_centos_version')
                            .and_raise_error(Puppet::DataBinding::LookupError, "Function lookup() did not find a value for the name 'test_module_01::not_el_centos_version'")
        end
      end

      # Test for confine on module name & module version in ce.
      it do
        is_expected.to run.with_params('test_module_01::fixed_confines')
                          .and_raise_error(Puppet::DataBinding::LookupError, "Function lookup() did not find a value for the name 'test_module_01::fixed_confines'")
      end
    end

    context "on #{os} with compliance_markup::::enforcement and an existing profile using tolerance above level 21" do
      let(:facts) do
        os_facts.merge('target_compliance_profile' => '01_profile_test', 'target_enforcement_tolerance' => '22')
      end
      let(:hieradata) { 'compliance-engine' }

      it do
        is_expected.to run.with_params('test_module_01::is_disabled')
                          .and_raise_error(Puppet::DataBinding::LookupError, "Function lookup() did not find a value for the name 'test_module_01::is_disabled'")
      end
      it { is_expected.to run.with_params('test_module_01::is_level_21').and_return(true) }
      it do
        is_expected.to run.with_params('test_module_01::is_level_41')
                          .and_raise_error(Puppet::DataBinding::LookupError, "Function lookup() did not find a value for the name 'test_module_01::is_level_41'")
      end
      it do
        is_expected.to run.with_params('test_module_01::is_level_61')
                          .and_raise_error(Puppet::DataBinding::LookupError, "Function lookup() did not find a value for the name 'test_module_01::is_level_61'")
      end
      it do
        is_expected.to run.with_params('test_module_01::is_level_81')
                          .and_raise_error(Puppet::DataBinding::LookupError, "Function lookup() did not find a value for the name 'test_module_01::is_level_81'")
      end
    end

    context "on #{os} with compliance_markup::::enforcement and an existing profile using tolerance above level 41" do
      let(:facts) do
        os_facts.merge('target_compliance_profile' => '01_profile_test', 'target_enforcement_tolerance' => '42')
      end
      let(:hieradata) { 'compliance-engine' }

      it do
        is_expected.to run.with_params('test_module_01::is_disabled')
                          .and_raise_error(Puppet::DataBinding::LookupError, "Function lookup() did not find a value for the name 'test_module_01::is_disabled'")
      end
      it { is_expected.to run.with_params('test_module_01::is_level_21').and_return(true) }
      it { is_expected.to run.with_params('test_module_01::is_level_41').and_return(true) }
      it do
        is_expected.to run.with_params('test_module_01::is_level_61')
                          .and_raise_error(Puppet::DataBinding::LookupError, "Function lookup() did not find a value for the name 'test_module_01::is_level_61'")
      end
      it do
        is_expected.to run.with_params('test_module_01::is_level_81')
                          .and_raise_error(Puppet::DataBinding::LookupError, "Function lookup() did not find a value for the name 'test_module_01::is_level_81'")
      end
    end

    context "on #{os} with compliance_markup::::enforcement and an existing profile using tolerance above level 61" do
      let(:facts) do
        os_facts.merge('target_compliance_profile' => '01_profile_test', 'target_enforcement_tolerance' => '62')
      end
      let(:hieradata) { 'compliance-engine' }

      it do
        is_expected.to run.with_params('test_module_01::is_disabled')
                          .and_raise_error(Puppet::DataBinding::LookupError, "Function lookup() did not find a value for the name 'test_module_01::is_disabled'")
      end
      it { is_expected.to run.with_params('test_module_01::is_level_21').and_return(true) }
      it { is_expected.to run.with_params('test_module_01::is_level_41').and_return(true) }
      it { is_expected.to run.with_params('test_module_01::is_level_61').and_return(true) }
      it do
        is_expected.to run.with_params('test_module_01::is_level_81')
                          .and_raise_error(Puppet::DataBinding::LookupError, "Function lookup() did not find a value for the name 'test_module_01::is_level_81'")
      end
    end

    context "on #{os} with compliance_markup::::enforcement and an existing profile using tolerance above level 81" do
      let(:facts) do
        os_facts.merge('target_compliance_profile' => '01_profile_test', 'target_enforcement_tolerance' => '82')
      end
      let(:hieradata) { 'compliance-engine' }

      it do
        is_expected.to run.with_params('test_module_01::is_disabled')
                          .and_raise_error(Puppet::DataBinding::LookupError, "Function lookup() did not find a value for the name 'test_module_01::is_disabled'")
      end
      it { is_expected.to run.with_params('test_module_01::is_level_21').and_return(true) }
      it { is_expected.to run.with_params('test_module_01::is_level_41').and_return(true) }
      it { is_expected.to run.with_params('test_module_01::is_level_61').and_return(true) }
      it { is_expected.to run.with_params('test_module_01::is_level_81').and_return(true) }
    end
  end
end
