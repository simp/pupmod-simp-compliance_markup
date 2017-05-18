require 'spec_helper'

# These can't work without an rspec-puppet patched to accept post_condition
xdescribe 'compliance_markup' do
  context 'supported operating systems' do
    on_supported_os.each do |os, facts|
      context "on #{os}" do
        context 'when using the enforcement backend' do
          before(:each) do
            @server_report_dir = Dir.mktmpdir

            @default_params = {
              'options' => {
                'server_report_dir' => @server_report_dir,
                'format'            => 'yaml'
              }
            }

            is_expected.to(compile.with_all_deps)
          end

          after(:each) do
            @default_params = {}
            @report = nil

            File.exist?(@server_report_dir) && FileUtils.remove_entry(@server_report_dir)
          end

          let(:report) {
            # There can be only one
            report_file = "#{params['options']['server_report_dir']}/#{facts[:fqdn]}/compliance_report.yaml"

            @report = YAML.load_file(report_file)

            @report
          }

          let(:pre_condition) {
            <<-EOM
              $compliance_profile = 'nist_800_53_rev4'
              $enforce_compliance_profile = ['nist_800_53_rev4', 'disa_stig']
            EOM
          }

          let(:post_condition) {
            <<-EOM
              class pam (
                # This invalid value should be flipped automatically
                $cracklib_difok = 1
              ) { }

              include pam
            EOM
          }

          let(:facts) { facts }
          let(:params) { @default_params }

          context 'with a custom site.pp' do
            it 'should have the policy-based value' do
              is_expected.to(create_class('pam').with_cracklib_difok(/^4$/))
            end

            it 'should have a server side compliance report node directory' do
              expect(File).to exist("#{params['options']['server_report_dir']}/#{facts[:fqdn]}")
            end

            it 'should have a server side compliance node report' do
              expect(File).to exist("#{params['options']['server_report_dir']}/#{facts[:fqdn]}/compliance_report.yaml")
            end

            it 'should have no failing checks' do
              expect( report['compliance_profiles']['nist_800_53_rev4']['non_compliant'] ).to be_empty
            end

            # This is limited to EL7 since that's all we have profiles for
            if ['RedHat', 'CentOS'].include?(facts[:os][:name])
              if ['7'].include?(facts[:os][:release][:major])
                context 'overrides should happen from left to right' do
                  let(:pre_condition) {
                    <<-EOM
                      $enforce_compliance_profile = ['disa_stig', 'nist_800_53_rev4']
                    EOM
                  }

                  it 'should have the higest order policy-based value' do
                    is_expected.to(create_class('pam').with_cracklib_difok(/^8$/))
                  end
                end
              end
            end
          end
        end
      end
    end
  end
end
