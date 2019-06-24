require 'spec_helper'

describe 'compliance_markup' do
  on_supported_os.each do |os, facts|
    let(:report_version) { '1.0.1' }

    context "on #{os}" do

      # This needs to be called as the very last item of a compile
      let(:post_condition) {<<-EOM
          include 'compliance_markup'
        EOM
      }

      context 'with data in modules' do
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

        let(:raw_report) {
          # There can be only one
          report_file = "#{params['options']['server_report_dir']}/#{facts[:fqdn]}/compliance_report.yaml"
          File.read(report_file)
        }

        let(:report) {
          @report = YAML.load(raw_report)
          @report
        }

        if ['RedHat', 'CentOS'].include?(facts[:os][:name])
          if ['6','7'].include?(facts[:os][:release][:major])

            context 'when running with the inbuilt data' do
              pre_condition_common = <<-EOM
                class auditd (
                  # This should trigger a finding
                  $at_boot = false
                ) { }

                include auditd
              EOM

              if facts[:os][:release][:major] == '6'
                let(:pre_condition) {
                  <<-EOM
                    $compliance_profile = ['nist_800_53_rev4']

                    #{pre_condition_common}
                  EOM
                }
              else
                let(:pre_condition) {
                  <<-EOM
                    $compliance_profile = ['disa_stig', 'nist_800_53_rev4']

                    #{pre_condition_common}
                  EOM
                }
              end

              let(:facts) { facts }
              let(:params) { @default_params }

              it 'should have a server side compliance report node directory' do
                expect(File).to exist("#{params['options']['server_report_dir']}/#{facts[:fqdn]}")
              end

              it 'should have a server side compliance node report' do
                expect(File).to exist("#{params['options']['server_report_dir']}/#{facts[:fqdn]}/compliance_report.yaml")
              end

              it 'should have a failing check' do
                expect( report['compliance_profiles']['nist_800_53_rev4']['non_compliant'] ).to_not be_empty
              end

              it 'should not have ruby serialized objects in the output' do
                expect(raw_report).to_not match(/!ruby/)
              end

              context 'when dumping the catalog compliance_map' do
                let(:catalog_dump) {
                  # There can be only one
                  File.read("#{params['options']['server_report_dir']}/#{facts[:fqdn]}/catalog_compliance_map.yaml")
                }

                let(:params){
                  _params = @default_params.dup
                  _params['options']['catalog_to_compliance_map'] = true
                  _params
                }

                it 'should have a generated catlaog' do
                  expect(File).to exist("#{params['options']['server_report_dir']}/#{facts[:fqdn]}/catalog_compliance_map.yaml")

                  expect(catalog_dump).to match(/GENERATED/)
                end

                it 'should not have Ruby serialized objects in the dump' do
                  expect(catalog_dump).to_not match(/!ruby/)
                end

                it 'should be valid YAML' do
                  expect {
                    YAML.load(catalog_dump)
                  }.to_not raise_exception
                end
              end
            end
          end
        end
      end

      [
        { :profile_type => 'Array'  },
        { :profile_type => 'String' }
      ].each do |data|
        context "with a fabricated test profile #{data[:profile_type]}" do

        profile_name = 'test_profile'
        case data[:profile_type]
          when 'Array'
            let(:pre_condition) {
              <<-EOM
                $compliance_profile = [
                  '#{profile_name}',
                  'other_profile'
                ]

                class test1 (
                  $arg1_1 = 'foo1_1',
                  $arg1_2 = 'foo1_2'
                ){
                  notify { 'bar': message => $arg1_1 }
                }

                class test2 {
                  class test3 (
                    $arg3_1 = 'foo3_1'
                  ) { }
                }

                define testdef1 (
                  $defarg1_1 = 'deffoo1_1'
                ) {
                  notify { 'testdef1': message => $defarg1_1}
                }

                define testdef2 (
                  $defarg1_2 = 'deffoo1_2',
                  $defarg2_2 = 'foo'
                ) {
                  notify { 'testdef2': message => $defarg1_2}
                }

                define one_off_inline {
                  compliance_map('other_profile', 'ONE_OFF', 'This is awesome')

                  notify { $name: }
                }

                include '::test1'
                include '::test2::test3'

                testdef1 { 'test_definition': }
                testdef2 { 'test_definition': defarg1_2 => 'test_bad' }
                one_off_inline { 'one off': }

                compliance_map('other_profile', 'TOP_LEVEL', 'Top level call')
              EOM
            }
          when 'String'
            let(:pre_condition) {
              <<-EOM
                $compliance_profile = '#{profile_name}'

                class test1 (
                  $arg1_1 = 'foo1_1',
                  $arg1_2 = 'foo1_2'
                ){
                  notify { 'bar': message => $arg1_1 }
                }

                class test2 {
                  class test3 (
                    $arg3_1 = 'foo3_1'
                  ) { }
                }

                define testdef1 (
                  $defarg1_1 = 'deffoo1_1'
                ) {
                  notify { 'testdef1': message => $defarg1_1}
                }

                define testdef2 (
                  $defarg1_2 = 'deffoo1_2',
                  $defarg2_2 = 'foo'
                ) {
                  notify { 'testdef2': message => $defarg1_2}
                }

                define one_off_inline {
                  compliance_map('other_profile', 'ONE_OFF', 'This is awesome')

                  notify { $name: }
                }

                include '::test1'
                include '::test2::test3'

                testdef1 { 'test_definition': }
                testdef2 { 'test_definition': defarg1_2 => 'test_bad' }
                one_off_inline { 'one off': }

                compliance_map('other_profile', 'TOP_LEVEL', 'Top level call')
              EOM
            }
        end

        let(:facts) { facts }

        ['yaml','json'].each do |report_format|
          context "with report format #{report_format}" do
            before(:each) do
              @server_report_dir = Dir.mktmpdir

              @default_params = {
                'options' => {
                  'server_report_dir' => @server_report_dir,
                  'format'            => report_format
                }
              }

              is_expected.to compile.with_all_deps
            end

            after(:each) do
              @default_params = {}
              @report = nil

              File.exist?(@server_report_dir) && FileUtils.remove_entry(@server_report_dir)
            end

            # Working around the fact that we can't actually figure out how to get
            # Puppet[:vardir]
            let(:compliance_file_resource) {
              catalogue.resources.select do |x|
                x.type == 'File' && x[:path] =~ /compliance_report.#{report_format}$/
              end.flatten.first
            }

            let(:report) {
              # There can be only one
              report_file = "#{params['options']['server_report_dir']}/#{facts[:fqdn]}/compliance_report.#{report_format}"

              if report_format == 'yaml'
                @report ||= YAML.load_file(report_file)
              elsif report_format == 'json'
                @report ||= JSON.load(File.read(report_file))
              end

              @report
            }

            context 'in a default run' do
              let(:hieradata) { 'passing_checks' }

              let(:params) { @default_params }

              it { is_expected.to(create_class('compliance_markup')) }

              it 'should not have a compliance File Resource' do
                expect(compliance_file_resource).to be_nil
              end

              it 'should have a server side compliance report node directory' do
                expect(File).to exist("#{params['options']['server_report_dir']}/#{facts[:fqdn]}")
              end

              it 'should have a server side compliance node report' do
                expect(File).to exist("#{params['options']['server_report_dir']}/#{facts[:fqdn]}/compliance_report.#{report_format}")
              end

              it 'should have the default extra data in the report' do
                expect(report['fqdn']).to eq(facts[:fqdn])
                expect(report['hostname']).to eq(facts[:hostname])
                expect(report['ipaddress']).to eq(facts[:ipaddress])
                expect(report['puppetserver_info']).to eq('local_compile')
              end
            end

            context 'when placing the report on the client' do
              let(:hieradata) { 'passing_checks' }

              let(:params) {
                _params = @default_params.dup

                _params['options'].merge!(
                  {
                    'client_report' => true,
                    'report_types'  => 'full'
                  }
                )

                _params
              }

              it { is_expected.to(create_class('compliance_markup')) }

              it 'should have a compliance File Resource' do
                expect(compliance_file_resource).to_not be_nil
              end

              it "should have a valid #{report_format} report" do
                file = nil;
                if report_format == 'yaml'
                  file = YAML.load(compliance_file_resource[:content]);
                elsif report_format == 'json'
                  file = JSON.load(compliance_file_resource[:content]);
                else
                  fail("Invalid report type '#{report_format}' specified")
                end
                version = file['version'];
                expect(version).to eq(report_version)
              end
            end

            context 'when checking system compliance' do
              let(:hieradata) { 'passing_checks' }

              let(:params) {
                _params = @default_params.dup

                _params['options'].merge!(
                  {
                    'report_types' => 'full'
                  }
                )

                _params
              }

              let(:all_resources) {
                compliant = report['compliance_profiles'][profile_name]['compliant'] || {}
                non_compliant = report['compliance_profiles'][profile_name]['non_compliant'] || {}

                compliant.merge(non_compliant)
              }

              it 'should have a valid version number' do
                expect( report['version'] ).to eq(report_version)
              end

              it 'should have a valid compliance profile' do
                expect( report['compliance_profiles'][profile_name] ).to_not be_empty
              end

              it 'should have a compliant report section' do
                expect( report['compliance_profiles'][profile_name]['compliant'] ).to_not be_empty
              end

              it 'should not include an empty non_compliant report section' do
                expect( report['compliance_profiles'][profile_name]['non_compliant'] ).to be_nil
              end

              it 'should have a documented_missing_resources section' do
                expect( report['compliance_profiles'][profile_name]['documented_missing_resources'] ).to_not be_empty
              end

              it 'should not show arguments in the documented_missing_resources section' do
                expect( report['compliance_profiles'][profile_name]['documented_missing_resources'].grep(/::arg/) ).to be_empty
              end

              it 'should not have documented_missing_resources that exist in the compliance reports' do

                known_resources = all_resources.keys.map do |resource|
                  if resource  =~ /\[(.*)\]/
                    all_resources[resource]['parameters'].keys.map do |param|
                      $1.split('::').first
                    end
                  else
                    nil
                  end
                end.flatten.uniq.compact.map(&:downcase)

                expect(
                  Array(report['compliance_profiles'][profile_name]['documented_missing_resources']) &
                  known_resources
                ).to be_empty
              end

              it 'should have a documented_missing_parameters section' do
                expect( report['compliance_profiles'][profile_name]['documented_missing_parameters'] ).to_not be_empty
              end

              it 'should not have documented_missing_parameters that exist in the compliance reports' do
                all_resources = report['compliance_profiles'][profile_name]['compliant'].merge(
                  report['compliance_profiles'][profile_name]['compliant'])

                known_parameters = all_resources.keys.map do |resource|
                  if resource  =~ /\[(.*)\]/
                    all_resources[resource]['parameters'].keys.map do |param|
                      $1 + '::' + param
                    end
                  else
                    nil
                  end
                end.flatten.compact.map(&:downcase)

                expect(
                  Array(report['compliance_profiles'][profile_name]['documented_missing_parameters']) &
                  known_parameters
                ).to be_empty
              end

              if (data[:profile_type] == 'Array')
                it 'should note the "other" profile' do
                  expect( report['compliance_profiles']['other_profile'] ).to_not be_empty
                end

                it 'should not include an empty compliant section for the "other" profile' do
                  expect( report['compliance_profiles']['other_profile']['compliant'] ).to be_nil
                end

                it 'should not include an empty non_compliant section for the "other" profile' do
                  expect( report['compliance_profiles']['other_profile']['non_compliant'] ).to be_nil
                end

                it 'should not include an empty documented_missing_resources section for the "other" profile' do
                  expect( report['compliance_profiles']['other_profile']['documented_missing_resources'] ).to be_nil
                end

                it 'should not include an empty documented_missing_parameters section for the "other" profile' do
                  expect( report['compliance_profiles']['other_profile']['documented_missing_parameters'] ).to be_nil
                end

                it 'should have a custom_entries section for the "other" profile' do
                  expect( report['compliance_profiles']['other_profile']['custom_entries'] ).to_not be_empty
                end

                it 'should have custom_entries for the "other" profile that have identifiers and notes' do

                  entry = report['compliance_profiles']['other_profile']['custom_entries']['One_off_inline::one off'].first
                  expect(entry['identifiers']).to_not be_empty
                  expect(entry['notes']).to_not be_empty
                end

                it 'should have a summary section of the "other" profile' do
                  expect( report['compliance_profiles']['other_profile']['summary'] ).to_not be_empty
                end

                it 'should have the number of compliant entries in the summary of the "other" profile' do
                  expect( report['compliance_profiles']['other_profile']['summary']['compliant'] ).to be_an(Integer)
                end

                it 'should have the number of non_compliant entries in the summary of the "other" profile' do
                  expect( report['compliance_profiles']['other_profile']['summary']['non_compliant'] ).to be_an(Integer)
                end

                it 'be appropriately compliant in the summary of the "other" profile' do
                  if report['compliance_profiles']['other_profile']['summary']['compliant'] + report['compliance_profiles']['other_profile']['summary']['non_compliant'] == 0
                    expect( report['compliance_profiles']['other_profile']['summary']['percent_compliant'] ).to eq(0)
                  else
                    expect( report['compliance_profiles']['other_profile']['summary']['percent_compliant'] ).to eq(100)
                  end
                end
              end
            end

            context 'when running with the default options' do
              let(:hieradata) { 'passing_checks' }

              let(:params) { @default_params }

              it 'should have a valid profile' do
                expect( report['compliance_profiles'][profile_name] ).to_not be_empty
              end

              it 'should not include an empty compliant report section' do
                expect( report['compliance_profiles'][profile_name]['compliant'] ).to be_nil
              end

              it 'should not include an empty non_compliant report section' do
                expect( report['compliance_profiles'][profile_name]['non_compliant'] ).to be_nil
              end

              it 'should not include an empty documented_missing_resources section' do
                expect( report['compliance_profiles'][profile_name]['documented_missing_resources'] ).to be_nil
              end

              it 'should have a documented_missing_parameters section' do
                expect( report['compliance_profiles'][profile_name]['documented_missing_parameters'] ).to_not be_empty
              end

              it 'should have a summary section' do
                expect( report['compliance_profiles'][profile_name]['summary'] ).to_not be_empty
              end

              it 'should have the number of compliant entries in the summary' do
                expect( report['compliance_profiles'][profile_name]['summary']['compliant'] ).to be_an(Integer)
              end

              it 'should have the number of non_compliant entries in the summary' do
                expect( report['compliance_profiles'][profile_name]['summary']['non_compliant'] ).to be_an(Integer)
              end

              it 'be appropriately compliant in the summary' do
                if report['compliance_profiles'][profile_name]['summary']['compliant'] + report['compliance_profiles'][profile_name]['summary']['non_compliant'] == 0
                  expect( report['compliance_profiles'][profile_name]['summary']['percent_compliant'] ).to eq(0)
                else
                  expect( report['compliance_profiles'][profile_name]['summary']['percent_compliant'] ).to eq(100)
                end
              end
            end

            context 'when an option in test1 has deviated' do
              let(:hieradata) { 'test1_deviation' }

              let(:params) { @default_params }

              let(:human_name) { 'Class[Test1]' }

              let(:invalid_entry) {
                report['compliance_profiles'][profile_name]['non_compliant'][human_name]['parameters']['arg1_1']
              }

              let(:params) {
                _params = @default_params.dup

                _params['options'].merge!(
                  {
                    'client_report' => true,
                    'report_types'  => 'full'
                  }
                )

                _params
              }

              it 'should have 1 non_compliant parameter' do
                expect( report['compliance_profiles'][profile_name]['non_compliant'][human_name]['parameters'].size ).to eq(1)
              end

              it 'should have an invalid entry with compliant value "bar1_1"' do
                expect( invalid_entry['compliant_value'] ).to eq('bar1_1')
              end

              it 'should have an invalid entry with system value "foo1_1"' do
                expect( invalid_entry['system_value'] ).to eq('foo1_1')
              end

              it 'should not have identical compliant and non_compliant entries' do
                compliant_entries = report['compliance_profiles'][profile_name]['compliant']
                non_compliant_entries = report['compliance_profiles'][profile_name]['non_compliant']

                compliant_entries.keys.each do |resource|
                  if non_compliant_entries[resource]
                    expect(
                      compliant_entries[resource]['parameters'].keys &
                      non_compliant_entries[resource]['parameters'].keys
                    ).to be_empty
                  end
                end
              end
            end

            context 'when an option in test2::test3 has deviated' do
              let(:hieradata) { 'test2_3_deviation' }

              let(:params) { @default_params }

              let(:human_name) { 'Class[Test2::Test3]' }

              let(:invalid_entry) {
                report['compliance_profiles'][profile_name]['non_compliant'][human_name]['parameters']['arg3_1']
              }

              it 'should have one non-compliant entry' do
                expect( report['compliance_profiles'][profile_name]['non_compliant'][human_name]['parameters'].size ).to eq(1)
              end

              it 'should have the non-compliant entry with compliant value "bar3_1"' do
                expect( invalid_entry['compliant_value'] ).to eq('bar3_1')
              end

              it 'should have the non-compliant entry with system value "foo3_1"' do
                expect( invalid_entry['system_value'] ).to eq('foo3_1')
              end
            end

            context 'without a compliance_profile variable set' do
              let(:pre_condition) {
                <<-EOM
                  include 'compliance_markup'
                EOM
              }

              let(:hieradata) { 'passing_checks' }

              it { is_expected.to(compile.with_all_deps) }
            end

            context 'with an unknown compliance_profile variable set' do
              let(:pre_condition) {
                <<-EOM
                  $compliance_profile = 'FOO BAR'
                EOM
              }

              let(:hieradata) { 'passing_checks' }

              it { is_expected.to(compile.with_all_deps) }
            end

            context 'with undefined values in the compliance hash' do
              let(:pre_condition) {
                <<-EOM
                  include 'compliance_markup'
                EOM
              }

              let(:hieradata) { 'undefined_values' }

              it { is_expected.to(compile.with_all_deps) }
            end

=begin
            # Unknown why this does not work
            xcontext 'without valid compliance data in Hiera' do
              let(:pre_condition) {''}
              # NOTE: No hieradata set!

              it 'should fail' do
                expect {
                  is_expected.to compile.with_all_deps
                }.to raise_error
              end
            end
=end
            end
          end
        end
      end
    end
  end
end
