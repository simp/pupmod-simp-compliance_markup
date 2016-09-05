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

      compliance_map()
    EOS
  }

  let(:compliant_hieradata) {
    <<-EOS
---
compliance :
  test_policy :
    test::var1 :
      'identifier' : 'TEST_POLICY1'
      'value' : 'test1'
    EOS
  }

  let(:non_compliant_hieradata) {
    <<-EOS
---
compliance :
  test_policy :
    test::var1 :
      'identifier' : 'TEST_POLICY1'
      'value' : 'not test1'
EOS
  }

  hosts.each do |host|
    context 'default parameters' do
      # Using puppet_apply as a helper
      it 'should work with no errors' do
        set_hieradata_on(host,compliant_hieradata)
        apply_manifest_on(host, manifest, :catch_failures => true)
      end

      it 'should be idempotent' do
        apply_manifest_on(host,manifest, :catch_changes => true)
      end
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
    end
  end
end
