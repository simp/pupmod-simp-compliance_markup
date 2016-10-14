require 'spec_helper'

describe 'compliance' do
  before(:all) do
    @tmpdir = Dir.mktmpdir('pupmod-compliance_test')
  end

  after(:each) do
    if File.directory?(@tmpdir)
      Dir.glob("#{@tmpdir}/*").each do |todel|
        FileUtils.rm_rf(todel)
      end
    end
  end

  after(:all) do
    if File.directory?(@tmpdir)
      FileUtils.rm_rf(@tmpdir)
    end
  end

  context 'supported operating systems' do
    on_supported_os.each do |os, facts|
      context "on #{os}" do
        let(:facts) { facts }

        before(:each) do
          Facter.stubs(:value).with(:puppet_vardir).returns(@tmpdir)
        end

        context 'parameter-only compliance map test' do
          let(:pre_condition) do
            "include 'compliance'"
          end
          it { is_expected.to compile.with_all_deps }
          it { is_expected.not_to contain_file("#{Facter.value(:vardir)}/compliance_report.yaml") }
        end

        context 'one parameter required compliance map test' do
          let(:pre_condition) do
            "include 'compliance::test2'"
          end

          it { is_expected.to compile.with_all_deps }
          it { is_expected.not_to contain_file("#{Facter.value(:vardir)}/compliance_report.yaml") }
        end

        shared_examples_for "a deviation run" do |profile, test_run, use_custom_content = false, extra_profiles = []|
          it {
            is_expected.to compile.with_all_deps
            is_expected.to contain_file("#{Facter.value(:vardir)}/compliance_report.yaml")
            report = YAML.load(@catalogue.resource("File[#{Facter.value(:vardir)}/compliance_report.yaml]")[:content])

            expect( report['compliance_profiles'][profile][test_run]['parameters'].size ).to eq(1)
            expect( report['compliance_profiles'][profile][test_run]['parameters'].first['compliant_param'] ).to eq('1')
            expect( report['compliance_profiles'][profile][test_run]['parameters'].first['system_param'] ).to eq('one')

            if use_custom_content
              unless extra_profiles.empty?
                extra_profiles.each do |content|
                  expect( report['compliance_profiles'][content][test_run]['custom_entries'].first['location'] ).to match(/\.pp:\d+/)
                end
              end
            end

            # Ensure that we don't have any custom items that are not in our
            # requested stack.
            expect( report['compliance_profiles'].keys - [profile,extra_profiles].flatten ).to be_empty
          }
        end

        context 'deviation from a compliance standard should be recorded' do
          compliance_profile = 'standard'

          let(:pre_condition) do
           %(
            $compliance_profile = #{compliance_profile}

            include 'compliance::test3'
            )
          end

          it_behaves_like "a deviation run", compliance_profile, 'Class::Compliance::Test3'
        end

        context 'multiple calls to compliance_map() should succeed' do
          compliance_profile = 'standard'

          let(:pre_condition) do
           %(
            $compliance_profile = #{compliance_profile}

            include 'compliance::test4'
            )
          end

          it_behaves_like "a deviation run", compliance_profile, 'Class::Compliance::Test4'
        end

        context 'custom content should be included in the report' do
          compliance_profile = 'standard'

          let(:pre_condition) do
           %(
            $compliance_profile = #{compliance_profile}

            include 'compliance::test5'
            )
          end

          it_behaves_like "a deviation run", compliance_profile, 'Class::Compliance::Test5', true
        end

        context 'all items in the "compliance_profile" array should be honored' do
          compliance_profile = 'standard'

          let(:pre_condition) do
           %(
            $compliance_profile = [#{compliance_profile}, 'not standard']

            include 'compliance::test6'
            )
          end

          it_behaves_like "a deviation run", compliance_profile, 'Class::Compliance::Test6', true, ['not standard']
        end

        context 'the function should work when called from a define' do
          compliance_profile = 'standard'
          def_name = 'test'

          let(:pre_condition) do
           %(
            $compliance_profile = [#{compliance_profile}, 'not standard']

            compliance::test7 { #{def_name}:
              # Put a non-compliant value here
              var_one => 'one'
            }
            )
          end

          # Note the difference in the 'test_run' parameter here, it is not a
          # class.
          it_behaves_like "a deviation run", compliance_profile, "Compliance::Test7::#{def_name}", true, ['not standard']
        end
      end
    end
  end
end
