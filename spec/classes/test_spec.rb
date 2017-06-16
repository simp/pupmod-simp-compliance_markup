require 'spec_helper'
# vim: set expandtab ts=2 sw=2:

# These can't work without an rspec-puppet patched to accept post_condition
describe 'compliance_markup::test' do
  context 'supported operating systems' do
    on_supported_os.each do |os, facts|
      context "on #{os}" do
        context 'when using the enforcement backend' do

          # This is limited to EL7 since that's all we have profiles for
          if ['RedHat', 'CentOS'].include?(facts[:os][:name])
            if ['7'].include?(facts[:os][:release][:major])

              profiles = [ 'disa', 'nist']
              profiles.each do |profile| 
                order = ([ profile ] + (profiles - [ profile ])).to_s
                context "when order = #{order}" do
                  let(:facts) { facts }
                  let(:hieradata){ "#{profile}_spec" }

                  it "should return #{profile}" do
                    is_expected.to(create_notify('compliance_markup::test').with_message("compliance_markup::test::testvariable = #{profile}"))
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
