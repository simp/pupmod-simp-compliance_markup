require 'spec_helper_acceptance'

test_name 'compliance_markup class'

describe 'compliance_markup class' do
  let(:manifest) {
    <<-EOS
      $compliance_profile = 'test_policy'

      class test (
        $var1 = 'test1'
      ) {
        compliance_map('test_policy', 'INTERNAL1', 'Test Note')
      }

      include 'test'
      include 'compliance_markup'
    EOS
  }

  let(:compliant_hieradata) {
    <<-EOS
---
compliance_map :
  test_policy :
    test::var1 :
      'identifiers' :
        - 'TEST_POLICY1'
      'value' : 'test1'
    EOS
  }

  let(:non_compliant_hieradata) {
    <<-EOS
---
compliance_map :
  test_policy :
    test::var1 :
      'identifiers' :
        - 'TEST_POLICY1'
      'value' : 'not test1'
EOS
  }

  hosts.each do |host|
    shared_examples 'a valid report' do
      before(:all) do
        @compliance_data = {
          :report => {}
        }
      end

      let(:fqdn) { fact_on(host, 'fqdn') }

      it 'should have a report' do
        tmpdir = Dir.mktmpdir
        begin
          Dir.chdir(tmpdir) do
            scp_from(host, "/opt/puppetlabs/puppet/cache/simp/compliance_reports/#{fqdn}/compliance_report.json", '.')

            expect {
              @compliance_data[:report] = JSON.load(File.read('compliance_report.json'))
            }.to_not raise_error
          end
        ensure
          FileUtils.remove_entry_secure tmpdir
        end
      end

      it 'should have host metadata' do
        expect(@compliance_data[:report]['fqdn']).to eq(fqdn)
      end

      it 'should have a compliance profile report' do
        expect(@compliance_data[:report]['compliance_profiles']).to_not be_empty
      end
    end

    context 'default parameters' do
      # Using puppet_apply as a helper
      it 'should work with no errors' do
        set_hieradata_on(host,compliant_hieradata)
        apply_manifest_on(host, manifest, :catch_failures => true)
      end

      it 'should be idempotent' do
        apply_manifest_on(host,manifest, :catch_changes => true)
      end

      it_behaves_like 'a valid report'
    end

    context 'non-compliant parameters' do
      # Using puppet_apply as a helper
      it 'should work with no errors' do
        set_hieradata_on(host,non_compliant_hieradata)
        apply_manifest_on(host, manifest, :catch_failures => true)
      end

      it 'should be idempotent' do
        apply_manifest_on(host,manifest, :catch_changes => true)
      end

      it_behaves_like 'a valid report'
    end
  end
end
