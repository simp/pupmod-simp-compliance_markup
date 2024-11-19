require 'spec_helper'
require 'fileutils'

describe 'compliance_markup' do
  on_supported_os.each do |os, os_facts|
    let(:report_version) { '1.0.1' }
    let(:fixtures) { File.expand_path('../fixtures', __dir__) }
    let(:dummy_module) { File.join(fixtures, 'modules', 'init_spec', 'SIMP', 'compliance_profiles') }

    context "on #{os}" do
      # This needs to be called as the very last item of a compile
      let(:post_condition) do
        <<~EOM
          include 'compliance_markup'
        EOM
      end

      context 'with data in modules' do
        let(:server_report_dir) { Dir.mktmpdir }
        let(:raw_report) do
          # There can be only one
          report_file = "#{params['options']['server_report_dir']}/#{facts[:networking][:fqdn]}/compliance_report.yaml"
          File.read(report_file)
        end
        let(:report) do
          YAML.safe_load(raw_report, aliases: true)
        end
        let(:default_params) do
          {
            'options' => {
              'server_report_dir' => server_report_dir,
              'format'            => 'yaml'
            }
          }
        end

        before(:each) do
          is_expected.to(compile.with_all_deps)
        end

        after(:each) do
          File.exist?(server_report_dir) && FileUtils.remove_entry(server_report_dir)
        end

        context 'when running with the inbuilt data' do
          pre_condition_common = <<~EOM
            class yum (
              # This should trigger a finding
              $config_options = {}
            ) { }

            include yum
          EOM

          let(:pre_condition) do
            <<~EOM
              $compliance_profile = ['disa_stig', 'nist_800_53:rev4']

              #{pre_condition_common}
            EOM
          end

          let(:facts) { os_facts }
          let(:params) { default_params }

          it 'has a server side compliance report node directory' do
            expect(File).to exist("#{params['options']['server_report_dir']}/#{facts[:networking][:fqdn]}")
          end

          it 'has a server side compliance node report' do
            expect(File).to exist("#{params['options']['server_report_dir']}/#{facts[:networking][:fqdn]}/compliance_report.yaml")
          end

          it 'has a failing check' do
            expect(report['compliance_profiles']['nist_800_53:rev4']['non_compliant']).not_to be_empty
          end

          it 'does not have ruby serialized objects in the output' do
            expect(raw_report).not_to match(%r{!ruby})
          end

          context 'when dumping the catalog compliance_map' do
            let(:catalog_dump) do
              # There can be only one
              File.read("#{params['options']['server_report_dir']}/#{facts[:networking][:fqdn]}/catalog_compliance_map.yaml")
            end

            let(:params) do
              p = Marshal.load(Marshal.dump(default_params))
              p['options']['catalog_to_compliance_map'] = true
              p
            end

            it 'has a generated catlaog' do
              expect(File).to exist("#{params['options']['server_report_dir']}/#{facts[:networking][:fqdn]}/catalog_compliance_map.yaml")

              expect(catalog_dump).to match(%r{GENERATED})
            end

            it 'does not have Ruby serialized objects in the dump' do
              expect(catalog_dump).not_to match(%r{!ruby})
            end

            it 'is valid YAML' do
              expect {
                YAML.safe_load(catalog_dump)
              }.not_to raise_exception
            end
          end
        end
      end

      [
        { profile_type: 'Array'  },
        { profile_type: 'String' },
      ].each do |data|
        context "with a fabricated test profile #{data[:profile_type]}" do
          profile_name = 'test_profile'
          case data[:profile_type]
          when 'Array'
            let(:pre_condition) do
              <<~EOM
                $compliance_profile = [
                  '#{profile_name}',
                  'other_profile'
                ]

                class test1 (
                  $arg1_1 = 'foo1_1',
                  $arg1_2 = 'foo1_2'
                ){
                  notify { 'bar': message => $arg1_1 }
                  compliance_markup::compliance_map('other_profile', 'IN_CLASS')
                  compliance_markup::compliance_map('other_profile', 'IN_CLASS2', 'Some Notes')
                }

                class test2 {
                  class test3 (
                    $arg3_1 = 'foo3_1'
                  ) { }
                }

                class test4 (
                  $list1 = ['item1','item2'],
                ){ }

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
                  compliance_markup::compliance_map('other_profile', 'ONE_OFF', 'This is awesome')

                  notify { $name: }
                }

                include 'test1'
                include 'test2::test3'
                include 'test4'

                testdef1 { 'test_definition': }
                testdef2 { 'test_definition': defarg1_2 => 'test_bad' }
                one_off_inline { 'one off': }

                compliance_markup::compliance_map('other_profile', 'TOP_LEVEL', 'Top level call')
              EOM
            end
          when 'String'
            let(:pre_condition) do
              <<~EOM
                $compliance_profile = '#{profile_name}'

                class test1 (
                  $arg1_1 = 'foo1_1',
                  $arg1_2 = 'foo1_2'
                ){
                  notify { 'bar': message => $arg1_1 }
                  compliance_markup::compliance_map('other_profile', 'IN_CLASS')
                  compliance_markup::compliance_map('other_profile', 'IN_CLASS2', 'Some Notes')
                }

                class test2 {
                  class test3 (
                    $arg3_1 = 'foo3_1'
                  ) { }
                }

                class test4 (
                  $list1 = ['item1','item2'],
                ){ }

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
                  compliance_markup::compliance_map('other_profile', 'ONE_OFF', 'This is awesome')

                  notify { $name: }
                }

                include '::test1'
                include '::test2::test3'
                include '::test4'

                testdef1 { 'test_definition': }
                testdef2 { 'test_definition': defarg1_2 => 'test_bad' }
                one_off_inline { 'one off': }

                compliance_markup::compliance_map('other_profile', 'TOP_LEVEL', 'Top level call')
              EOM
            end
          end

          let(:facts) { os_facts }

          ['yaml', 'json'].each do |report_format|
            context "with report format #{report_format}" do
              let(:server_report_dir) { Dir.mktmpdir }
              # Working around the fact that we can't actually figure out how to get
              # Puppet[:vardir]
              let(:compliance_file_resource) do
                catalogue.resources.select { |x|
                  x.type == 'File' && x[:path] =~ %r{compliance_report.#{report_format}$}
                }.flatten.first
              end
              let(:report) do
                # There can be only one
                report_file = "#{params['options']['server_report_dir']}/#{facts[:networking][:fqdn]}/compliance_report.#{report_format}"

                if report_format == 'yaml'
                  YAML.load_file(report_file)
                elsif report_format == 'json'
                  JSON.parse(File.read(report_file))
                end
              end
              let(:default_params) do
                {
                  'options' => {
                    'server_report_dir' => server_report_dir,
                    'format'            => report_format
                  }
                }
              end

              before(:each) do
                allow(File).to receive(:read).and_call_original
                allow(Dir).to receive(:glob).and_call_original

                dummy_files = []
                Dir.glob(File.join(fixtures, 'hieradata', active_data, 'SIMP', 'compliance_profiles', '*.yaml')).each do |file|
                  dummy_file = File.join(dummy_module, File.basename(file))
                  allow(File).to receive(:read).with(dummy_file, any_args).and_return(File.read(file))
                  dummy_files << dummy_file
                end

                allow(Dir).to receive(:glob).with(%r{\bSIMP/compliance_profiles\b.*/\*\*/\*\.yaml$}, any_args) do |_, &block|
                  dummy_files.each(&block)
                end

                is_expected.to compile.with_all_deps
              end

              after(:each) do
                File.exist?(server_report_dir) && FileUtils.remove_entry(server_report_dir)
              end

              context 'in a default run' do
                let(:active_data) { 'passing_checks' }
                let(:params) { default_params }

                it { is_expected.to(create_class('compliance_markup')) }

                it 'does not have a compliance File Resource' do
                  expect(compliance_file_resource).to be_nil
                end

                it 'has a server side compliance report node directory' do
                  expect(File).to exist("#{params['options']['server_report_dir']}/#{facts[:networking][:fqdn]}")
                end

                it 'has a server side compliance node report' do
                  expect(File).to exist("#{params['options']['server_report_dir']}/#{facts[:networking][:fqdn]}/compliance_report.#{report_format}")
                end

                it 'has a summary for each profile' do
                  report['compliance_profiles'].each_value do |value|
                    expect(value['summary']).not_to be_nil
                    expect(value['summary']).not_to be_empty

                    all_report_types = [
                      'compliant',
                      'non_compliant',
                      'documented_missing_parameters',
                      'documented_missing_classes',
                      'percent_compliant',
                    ]
                    expect(value['summary'].keys - all_report_types).to eq([])
                  end
                end

                it 'has the default extra data in the report' do
                  expect(report['fqdn']).to eq(facts[:networking][:fqdn])
                  expect(report['hostname']).to eq(facts[:networking][:hostname])
                  expect(report['ipaddress']).to eq(facts[:networking][:ip])
                  expect(report['puppetserver_info']).to eq(server_facts_hash.merge({ 'environment' => environment }))
                end

                if data[:profile_type] == 'Array'
                  it 'has the expected custom entries' do
                    custom_entries = report['compliance_profiles']['other_profile']['custom_entries']

                    expect(custom_entries).not_to be_nil
                    expect(custom_entries).not_to be_empty
                    expect(custom_entries.keys).to match_array([
                                                                 'Class::Test1',
                                                                 'Class::main',
                                                                 'One_off_inline::one off',
                                                               ])
                    expect(custom_entries['Class::Test1'].size).to eq(2)
                    expect(custom_entries['Class::Test1'].first['identifiers']).to eq('IN_CLASS')
                    expect(custom_entries['Class::Test1'].last['identifiers']).to eq('IN_CLASS2')
                    expect(custom_entries['Class::main'].size).to eq(1)
                    expect(custom_entries['Class::main'].first['identifiers']).to eq('TOP_LEVEL')
                    expect(custom_entries['One_off_inline::one off'].size).to eq(1)
                    expect(custom_entries['One_off_inline::one off'].first['identifiers']).to eq('ONE_OFF')
                  end
                else
                  it 'does not have entries from the "other_profile"' do
                    expect(report['compliance_profiles']['other_profile']).to be_nil
                  end
                end
              end

              context 'when placing the report on the client' do
                let(:active_data) { 'passing_checks' }

                let(:params) do
                  p = Marshal.load(Marshal.dump(default_params))

                  p['options'].merge!(
                    {
                      'client_report' => true,
                      'report_types'  => ['full']
                    },
                  )

                  p
                end

                let(:client_report) do
                  report_content = compliance_file_resource[:content]

                  if report_format == 'yaml'
                    YAML.safe_load(report_content)
                  elsif report_format == 'json'
                    JSON.parse(report_content)
                  end
                end

                it { is_expected.to(create_class('compliance_markup')) }

                it 'has a compliance File Resource' do
                  expect(compliance_file_resource).not_to be_nil
                end

                it "has a valid #{report_format} report" do
                  expect(client_report['version']).to eq(report_version)
                end

                it 'does not have a timestamp' do
                  expect(client_report['timestamp']).to be_nil
                end

                context 'with client_report_timestamp = true' do
                  let(:params) do
                    p = Marshal.load(Marshal.dump(default_params))

                    p['options'].merge!(
                      {
                        'client_report'           => true,
                        'client_report_timestamp' => true,
                        'report_types'            => ['full']
                      },
                    )

                    p
                  end

                  it "has a valid #{report_format} report" do
                    expect(client_report['version']).to eq(report_version)
                  end

                  it 'has a timestamp' do
                    expect(client_report['timestamp']).not_to be_nil
                  end
                end
              end

              context 'when checking system compliance' do
                let(:active_data) { 'passing_checks' }

                let(:params) do
                  p = Marshal.load(Marshal.dump(default_params))

                  p['options']['report_types'] = ['full']

                  p
                end

                let(:all_resources) do
                  compliant = report['compliance_profiles'][profile_name]['compliant'] || {}
                  non_compliant = report['compliance_profiles'][profile_name]['non_compliant'] || {}

                  compliant.merge(non_compliant)
                end

                it 'has a valid version number' do
                  expect(report['version']).to eq(report_version)
                end

                it 'has a timestamp' do
                  expect(report['timestamp']).not_to be_nil
                end

                it 'has a valid compliance profile' do
                  expect(report['compliance_profiles'][profile_name]).not_to be_empty
                end

                it 'has a compliant report section' do
                  expect(report['compliance_profiles'][profile_name]['compliant']).not_to be_empty
                end

                it 'does not include an empty non_compliant report section' do
                  expect(report['compliance_profiles'][profile_name]['non_compliant']).not_to be_empty
                end

                it 'has a documented_missing_resources section' do
                  expect(report['compliance_profiles'][profile_name]['documented_missing_resources']).not_to be_empty
                end

                it 'does not show arguments in the documented_missing_resources section' do
                  expect(report['compliance_profiles'][profile_name]['documented_missing_resources'].grep(%r{::arg})).to be_empty
                end

                it 'does not have documented_missing_resources that exist in the compliance reports' do
                  known_resources = all_resources.keys.map { |resource|
                    if resource =~ %r{\[(.*)\]}
                      all_resources[resource]['parameters'].keys.map do |_param|
                        Regexp.last_match(1).split('::').first
                      end
                    else
                      nil
                    end
                  }.flatten.uniq.compact.map(&:downcase)

                  expect(
                    Array(report['compliance_profiles'][profile_name]['documented_missing_resources']) &
                    known_resources,
                  ).to be_empty
                end

                it 'has a documented_missing_parameters section' do
                  expect(report['compliance_profiles'][profile_name]['documented_missing_parameters']).not_to be_empty
                end

                it 'does not have documented_missing_parameters that exist in the compliance reports' do
                  all_resources = report['compliance_profiles'][profile_name]['compliant'].merge(
                    report['compliance_profiles'][profile_name]['compliant'],
                  )

                  known_parameters = all_resources.keys.map { |resource|
                    if resource =~ %r{\[(.*)\]}
                      all_resources[resource]['parameters'].keys.map do |param|
                        Regexp.last_match(1) + '::' + param
                      end
                    else
                      nil
                    end
                  }.flatten.compact.map(&:downcase)

                  expect(
                    Array(report['compliance_profiles'][profile_name]['documented_missing_parameters']) &
                    known_parameters,
                  ).to be_empty
                end

                if data[:profile_type] == 'Array'
                  it 'notes the "other" profile' do
                    expect(report['compliance_profiles']['other_profile']).not_to be_empty
                  end

                  it 'does not include an empty compliant section for the "other" profile' do
                    expect(report['compliance_profiles']['other_profile']['compliant']).to be_nil
                  end

                  it 'does not include an empty non_compliant section for the "other" profile' do
                    expect(report['compliance_profiles']['other_profile']['non_compliant']).to be_nil
                  end

                  it 'does not include an empty documented_missing_resources section for the "other" profile' do
                    expect(report['compliance_profiles']['other_profile']['documented_missing_resources']).to be_nil
                  end

                  it 'does not include an empty documented_missing_parameters section for the "other" profile' do
                    expect(report['compliance_profiles']['other_profile']['documented_missing_parameters']).to be_nil
                  end

                  it 'has a custom_entries section for the "other" profile' do
                    expect(report['compliance_profiles']['other_profile']['custom_entries']).not_to be_empty
                  end

                  it 'has custom_entries for the "other" profile that have identifiers and notes' do
                    entry = report['compliance_profiles']['other_profile']['custom_entries']['One_off_inline::one off'].first
                    expect(entry['identifiers']).not_to be_empty
                    expect(entry['notes']).not_to be_empty
                  end

                  it 'has a summary section of the "other" profile' do
                    expect(report['compliance_profiles']['other_profile']['summary']).not_to be_empty
                  end

                  it 'has the number of compliant entries in the summary of the "other" profile' do
                    expect(report['compliance_profiles']['other_profile']['summary']['compliant']).to be_an(Integer)
                  end

                  it 'has the number of non_compliant entries in the summary of the "other" profile' do
                    expect(report['compliance_profiles']['other_profile']['summary']['non_compliant']).to be_an(Integer)
                  end

                  it 'be appropriately compliant in the summary of the "other" profile' do
                    if report['compliance_profiles']['other_profile']['summary']['compliant'] + report['compliance_profiles']['other_profile']['summary']['non_compliant'] == 0
                      expect(report['compliance_profiles']['other_profile']['summary']['percent_compliant']).to eq(0)
                    else
                      expect(report['compliance_profiles']['other_profile']['summary']['percent_compliant']).to eq(100)
                    end
                  end
                end
              end

              context 'when running with the default options' do
                let(:active_data) { 'passing_checks' }
                let(:params) { default_params }

                it 'has a valid profile' do
                  expect(report['compliance_profiles'][profile_name]).not_to be_empty
                end

                it 'does not include an empty compliant report section' do
                  expect(report['compliance_profiles'][profile_name]['compliant']).to be_nil
                end

                it 'does not include an empty non_compliant report section' do
                  expect(report['compliance_profiles'][profile_name]['non_compliant']).not_to be_empty
                end

                it 'does not include an empty documented_missing_resources section' do
                  expect(report['compliance_profiles'][profile_name]['documented_missing_resources']).to be_nil
                end

                it 'has a documented_missing_parameters section' do
                  expect(report['compliance_profiles'][profile_name]['documented_missing_parameters']).not_to be_empty
                end

                it 'has a summary section' do
                  expect(report['compliance_profiles'][profile_name]['summary']).not_to be_empty
                end

                it 'has the number of compliant entries in the summary' do
                  expect(report['compliance_profiles'][profile_name]['summary']['compliant']).to be_an(Integer)
                end

                it 'has the number of non_compliant entries in the summary' do
                  expect(report['compliance_profiles'][profile_name]['summary']['non_compliant']).to be_an(Integer)
                end

                it 'be appropriately compliant in the summary' do
                  if report['compliance_profiles'][profile_name]['summary']['compliant'] + report['compliance_profiles'][profile_name]['summary']['non_compliant'] == 0
                    expect(report['compliance_profiles'][profile_name]['summary']['percent_compliant']).to eq(0)
                  else
                    # The bad defined type causes this
                    expect(report['compliance_profiles'][profile_name]['summary']['percent_compliant']).to eq(75)
                  end
                end
              end

              context 'when an option in test4 has an escaped knockout prefix' do
                let(:active_data) { 'escaped_knockout' }

                let(:facts) do
                  os_facts.merge(
                    {
                      target_compliance_profile: profile_name,
                      target_enforcement_tolerance: 40
                    },
                  )
                end

                let(:hieradata) { 'compliance-engine' }

                let(:human_name) { 'Class[Test4]' }

                let(:params) do
                  p = Marshal.load(Marshal.dump(default_params))

                  p['options'].merge!(
                    {
                      'client_report' => true,
                      'report_types'  => ['full']
                    },
                  )

                  p
                end

                it { is_expected.to(create_class('compliance_markup')) }

                it 'has 0 non_compliant parameters' do
                  expect(report['compliance_profiles'][profile_name]['summary']['non_compliant']).to eq(0)
                end
              end

              context 'when an option in test1 has deviated' do
                let(:active_data) { 'test1_deviation' }

                let(:human_name) { 'Class[Test1]' }

                let(:invalid_entry) do
                  report['compliance_profiles'][profile_name]['non_compliant'][human_name]['parameters']['arg1_1']
                end

                let(:params) do
                  p = Marshal.load(Marshal.dump(default_params))

                  p['options'].merge!(
                    {
                      'client_report' => true,
                      'report_types'  => ['full']
                    },
                  )

                  p
                end

                it 'has 1 non_compliant parameter' do
                  expect(report['compliance_profiles'][profile_name]['non_compliant'][human_name]['parameters'].size).to eq(1)
                end

                it 'has an invalid entry with compliant value "bar1_1"' do
                  expect(invalid_entry['compliant_value']).to eq('bar1_1')
                end

                it 'has an invalid entry with system value "foo1_1"' do
                  expect(invalid_entry['system_value']).to eq('foo1_1')
                end

                it 'does not have identical compliant and non_compliant entries' do
                  compliant_entries = report['compliance_profiles'][profile_name]['compliant']
                  non_compliant_entries = report['compliance_profiles'][profile_name]['non_compliant']

                  compliant_entries.each_key do |resource|
                    next unless non_compliant_entries[resource]
                    expect(
                      compliant_entries[resource]['parameters'].keys &
                      non_compliant_entries[resource]['parameters'].keys,
                    ).to be_empty
                  end
                end
              end

              context 'when an option in test2::test3 has deviated' do
                let(:active_data) { 'test2_3_deviation' }

                let(:params) { default_params }

                let(:human_name) { 'Class[Test2::Test3]' }

                let(:invalid_entry) do
                  report['compliance_profiles'][profile_name]['non_compliant'][human_name]['parameters']['arg3_1']
                end

                it 'has one non-compliant entry' do
                  expect(report['compliance_profiles'][profile_name]['non_compliant'][human_name]['parameters'].size).to eq(1)
                end

                it 'has the non-compliant entry with compliant value "bar3_1"' do
                  expect(invalid_entry['compliant_value']).to eq('bar3_1')
                end

                it 'has the non-compliant entry with system value "foo3_1"' do
                  expect(invalid_entry['system_value']).to eq('foo3_1')
                end
              end

              context 'without a compliance_profile variable set' do
                let(:pre_condition) do
                  <<~EOM
                    include 'compliance_markup'
                  EOM
                end

                let(:active_data) { 'passing_checks' }

                it { is_expected.to(compile.with_all_deps) }
              end

              context 'with an unknown compliance_profile variable set' do
                let(:pre_condition) do
                  <<~EOM
                    $compliance_profile = 'FOO BAR'
                  EOM
                end

                let(:active_data) { 'passing_checks' }

                it { is_expected.to(compile.with_all_deps) }
              end

              context 'with undefined values in the compliance hash' do
                let(:pre_condition) do
                  <<~EOM
                    include 'compliance_markup'
                  EOM
                end

                let(:active_data) { 'undefined_values' }

                it { is_expected.to(compile.with_all_deps) }
              end
            end
          end
        end
      end
    end
  end
end
