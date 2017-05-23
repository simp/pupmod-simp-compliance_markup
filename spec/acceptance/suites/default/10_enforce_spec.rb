require 'spec_helper_acceptance'

test_name 'compliance_markup class enforcement'

describe 'compliance_markup class enforcement' do

  def set_profile_data_on(host, profile_name, profile_data)
    hiera_yaml = <<-EOM
---
:backends:
  - yaml
  - compliance_markup_enforce
:yaml:
  :datadir: "/etc/puppetlabs/code/environments/%{environment}/hieradata"
:compliance_markup_enforce:
  :datadir: "/etc/puppetlabs/code/environments/%{environment}/hieradata"
:hierarchy:
  - "compliance_profiles/%{compliance_profile}"
  - default
:logger: console
    EOM

    Dir.mktmpdir do |dir|
      tmp_yaml = File.join(dir, 'hiera.yaml')
      File.open(tmp_yaml, 'w') do |fh|
        fh.puts hiera_yaml
      end

      host.do_scp_to(tmp_yaml, '/etc/puppetlabs/puppet/hiera.yaml', {})
    end

    Dir.mktmpdir do |dir|
      tmp_profiles = File.join(dir, 'compliance_profiles')
      FileUtils.mkdir_p(tmp_profiles)
      File.open(File.join(tmp_profiles, profile_name + '.yaml'), 'w') do |fh|
        fh.puts(profile_data)
        fh.flush

        hiera_dir = File.join(host.puppet['codedir'], 'environments', 'production', 'hieradata')

        host.do_scp_to(tmp_profiles, hiera_dir, {})
      end
    end
  end

  let(:base_manifest) {
    <<-EOS
      # Needed for Hiera
      $compliance_profile = 'base_profile'
      $enforce_compliance_profile = 'base_profile'

      include 'compliance_markup::enforcement_helper'
      include 'useradd'
    EOS
  }

  let(:base_hieradata) { <<-EOF
---
compliance_markup::enforcement_helper::profiles:
  - base_profile
  - extra_profile

compliance_map:
  version: 1.0.0
  base_profile:
    useradd::shells:
      identifiers:
        - FOO
        - BAR
      notes: Nothing fun really
      value:
        - /bin/sh
        - /bin/bash
        - /sbin/nologin
        - /bin/test_shell
    EOF
  }

  let(:extra_manifest) {
    <<-EOS
      # Needed for Hiera
      $compliance_profile = 'base_profile'

      include 'compliance_markup::enforcement_helper'

      include 'useradd'

      include 'compliance_markup::validate'
    EOS
  }

  let(:extra_hieradata) { <<-EOF
---
compliance_map:
  version: 1.0.0
  extra_profile:
    useradd::shells:
      identifiers:
        - FOO2
        - BAR2
      notes: Nothing fun really
      value:
        - /bin/extra_shell
    EOF
  }

  hosts.each do |host|
    context 'base setup' do
      # Using puppet_apply as a helper
      it 'should work with no errors' do
        apply_manifest_on(host, 'include "useradd"', :catch_failures => true)
      end

      it 'should be idempotent' do
        apply_manifest_on(host, base_manifest, :catch_changes => true)
      end

      it 'should have /bin/sh in /etc/shells' do
        result = on(host, 'cat /etc/shells').output.strip
        expect(result).to match(%r(/bin/sh))
      end

      it 'should not have /bin/test_shell in /etc/shells' do
        result = on(host, 'cat /etc/shells').output.strip
        expect(result).to_not match(%r(/bin/test_shell))
      end
    end

    context 'with a single compliance map' do
      # Using puppet_apply as a helper
      it 'should work with no errors' do
        set_profile_data_on(host, 'base_profile', base_hieradata)
        apply_manifest_on(host, base_manifest, :catch_failures => true)
      end

      it 'should be idempotent' do
        apply_manifest_on(host, base_manifest, :catch_changes => true)
      end

      it 'should have /bin/sh in /etc/shells' do
        result = on(host, 'cat /etc/shells').output.strip
        expect(result).to match(%r(/bin/sh))
      end

      it 'should have /bin/test_shell in /etc/shells' do
        result = on(host, 'cat /etc/shells').output.strip
        expect(result).to match(%r(/bin/test_shell))
      end

      it 'should not have /bin/stacked_shell in /etc/shells' do
        result = on(host, 'cat /etc/shells').output.strip
        expect(result).to_not match(%r(/bin/stacked_shell))
      end
    end

    context 'with a single compliance map' do
      # Using puppet_apply as a helper
      it 'should work with no errors' do
        set_profile_data_on(host, 'extra_profile', extra_hieradata)
        apply_manifest_on(host, extra_manifest, :catch_failures => true)
      end

      it 'should be idempotent' do
        apply_manifest_on(host, extra_manifest, :catch_changes => true)
      end

      it 'should have /bin/sh in /etc/shells' do
        result = on(host, 'cat /etc/shells').output.strip
        expect(result).to match(%r(/bin/sh))
      end

      it 'should have /bin/test_shell in /etc/shells' do
        result = on(host, 'cat /etc/shells').output.strip
        expect(result).to match(%r(/bin/test_shell))
      end

      it 'should not have /bin/extra_shell in /etc/shells' do
        result = on(host, 'cat /etc/shells').output.strip
        expect(result).to_not match(%r(/bin/extra_shell))
      end
    end
  end
end
