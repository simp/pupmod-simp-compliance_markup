require 'spec_helper_acceptance'

test_name 'compliance_markup class'

describe 'compliance_markup class' do
  let(:manifest) do
    <<~EOS
      $compliance_profile = 'test_policy'

      class test (
        $var1 = 'test1'
      ) {
        compliance_markup::compliance_map('test_policy', 'INTERNAL', 'Note')
      }

      include 'test'
      include 'compliance_markup'
    EOS
  end

  let(:compliant_hieradata) do
    <<~EOS
    ---
    compliance_map:
      test_policy:
        test::var1:
          'identifiers':
            - 'TEST_POLICY1'
          'value': 'test1'
    EOS
  end

  let(:non_compliant_hieradata) do
    <<~EOS
    ---
    compliance_map :
      test_policy :
        test::var1 :
          'identifiers' :
            - 'TEST_POLICY1'
          'value' : 'not test1'
    EOS
  end

  hosts.each do |host|
    shared_examples 'a valid report' do
      let(:compliance_data) do
        tmpdir = Dir.mktmpdir
        value = nil
        begin
          Dir.chdir(tmpdir) do
            scp_from(host, "/opt/puppetlabs/puppet/cache/simp/compliance_reports/#{fqdn}/compliance_report.json", '.')

            value = {
              report: JSON.parse(File.read('compliance_report.json'))
            }
          end
        ensure
          FileUtils.remove_entry_secure tmpdir
        end
        value
      end

      let(:fqdn) { fact_on(host, 'networking.fqdn') }

      it 'has a report' do
        expect(compliance_data).not_to be_nil
        expect(compliance_data[:report]).not_to be_nil
        expect(compliance_data[:report]).not_to be_instance_of(Hash)
        expect(compliance_data[:report]).not_to be_empty
      end

      it 'has host metadata' do
        expect(compliance_data[:report]['fqdn']).to eq(fqdn)
      end

      it 'has a compliance profile report' do
        expect(compliance_data[:report]['compliance_profiles']).not_to be_empty
      end
    end

    context 'default parameters' do
      # Using puppet_apply as a helper
      it 'works with no errors' do
        set_hieradata_on(host, compliant_hieradata)
        apply_manifest_on(host, manifest, catch_failures: true)
      end

      it 'is idempotent' do
        apply_manifest_on(host, manifest, catch_changes: true)
      end

      it_behaves_like 'a valid report'
    end

    context 'non-compliant parameters' do
      # Using puppet_apply as a helper
      it 'works with no errors' do
        set_hieradata_on(host, non_compliant_hieradata)
        apply_manifest_on(host, manifest, catch_failures: true)
      end

      it 'is idempotent' do
        apply_manifest_on(host, manifest, catch_changes: true)
      end

      it_behaves_like 'a valid report'
    end
  end
end
