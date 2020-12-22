# @summary Provides a mechanism for mapping compliance data to settings in Puppet
#
# It should be used **once**, after all of your classes have been included
# and is designed for use in classes to validate that parameters are
# properly set.
#
# The easiest method for doing this is to add it as the **last** line of
# ``site.pp``.
#
# When called, the parameters of all classes will be evaluated against
# global scope variables followed by data from lookup().
#
# The variable space against which the class parameters will be evaluated
# must be structured as the following hash:
#
#   compliance_map :
#     <compliance_profile> :
#       <class_name>::<parameter> :
#         'identifiers' :
#           - 'ID String'
#         'value'      : 'Compliant Value'
#
# For instance, if you were mapping to NIST 800-53 in the SSH class, you
# could use something like the following in Hiera:
#
#   compliance_map :
#     nist_800_53 :
#       ssh::permit_root_login :
#         'identifiers' :
#           - 'CCE-1234'
#         'value'      : false
#
# 'value' items have some special properties. Hashes and Arrays will
# be matched using '==' in Ruby.
#
# Everything else will be converted to a String and can be provided a Ruby
# regular expression of the following format: 're:REGEX' where 'REGEX' does
# **not** include the starting and trailing slashes.
#
#   Example:
#     'value' : 're:oo'
#
#     Matches: 'foo' and 'boo' but not 'bar'
#
# You may also add compliance data directly to your modules outside of a
# parameter mapping. This is useful if you have more advanced logic that is
# required to meet a particular internal requirement.
#
# NOTE: The parser does not know what line number and, possibly, what file
# the function is being called from based on the version of the Puppet
# parser being used.
#
# ## Global Options
#
# If a Hash is passed as the only argument, then this will configure the
# global report settings.
#
# The following options are supported:
#
#   **:report_types**
#
#   Default: [ 'non_compliant', 'unknown_parameters', 'custom_entries' ]
#
#   A String, or Array that denotes which types of reports should be
#   generated.
#
#   Valid Types:
#     **full**               => The full report, with all other types
#                               included.
#     **non_compliant**      => Items that differ from the reference
#                               will be reported.
#     **compliant**          => Compliant items will be reported.
#     **unknown_resources**  => Reference resources without a
#                               system value will be reported.
#     **unknown_parameters** => Reference parameters without a system
#                               value will be reported.
#     **custom_entries**     => Any one-off custom calls to
#                               compliance_map will be reported.
#
#   **:site_data**
#
#   Default: None
#
#   A valid *Hash* that will be converted *as passed* and emitted
#   into your node compliance report.
#
#   This can be used to add site-specific or other information to the
#   report that may be useful for post-processing.
#
#   **:format**
#
#   Default: 'json'
#
#   A String that indicates what output style to use. Valid values are
#   'json' and 'yaml'.
#
#   **:client_report**
#
#     Default: false
#
#     A Boolean which, if set, will place a copy of the report on the
#     client itself. This will ensure that PuppetDB will have a copy of the
#     report for later processing.
#
#   **:server_report**
#
#     Default: true
#
#     A Boolean which, if set, will store a copy of the
#     report on the Server.
#
#   **:server_report_dir**
#
#     Default: Puppet[:vardir]/simp/compliance_reports
#
#     An Absolute Path that specifies the location on
#     the *server* where the reports should be stored.
#
#     A directory will be created for each FQDN that
#     has a report.
#
#  **:default_map**
#
#     Default: None
#
#     The default map that should be used if no others can be found. This
#     will probably never be manually set during normal usage via the
#     compliance_markup module
#
#   **:catalog_to_compliance_map**
#
#     Default: false
#
#     A Boolean which, if set, will dump a compatible compliance_map of
#     *all* resources and defines that are in the current catalog.
#
#     This will be written to ``server_report_dir`` prefaced by the unique catalog ID.
#
#     NOTE: This is an experimental feature and subject to change without notice
#
# Example:
#   # Only non-compilant entries and only store them on the client and the
#   # server
#   compliance_map({
#     :report_types  => [
#       'non_compliant',
#       'unknown_parameters',
#       'custom_entries'
#     ],
#     :client_report => true,
#     :server_report => true
#   })
#
# ## Custom Content
#
# The following optional **ordered** parameters may be used to add your own
# compliance data at any location:
#
#   :compliance_profile => 'A String, or Array, that denotes the compliance
#                           profile(s) to which you are mapping.'
#   :identifier         => 'A unique identifier String or Array for the
#                           policy to which you are mapping.'
#   :notes              => 'An *optional* String that allows for arbitrary
#                           notes to include in the compliance report'
#
# Example:
#   if $circumstance {
#     compliance_map('nist_800_53','CCE-1234','Note about this section')
#     ...code that applies CCE-1234...
#   }
#
#Puppet::Functions.create_function(:'compliance_markup::compliance_map') do
Puppet::Functions.create_function(:'compliance_markup::compliance_map', Puppet::Functions::InternalFunction) do

  # @param map_data
  #   The full Hash of mapping data
  #
  # @return [Nil]
  #
  dispatch :compliance_map do
    required_param 'Hash', :map_data
    # See: https://github.com/puppetlabs/puppet-specifications/blob/master/language/func-api.md#experimental--internal-features
    scope_param()
  end

  # @param compliance_profile
  #   Denotes the compliance profile(s) to which you are mapping
  #
  # @param identifiers
  #   A unique identifier for the policy to which you are mapping
  #
  # @param notes
  #   Allows for arbitrary notes to include in the compliance report
  #
  # @return [Nil]
  #
  dispatch :compliance_map_inline do
    required_param 'Variant[String[1], Array[String[1]]]', :compliance_profile
    required_param 'Variant[String[1], Array[String[1]]]', :identifiers
    optional_param 'String[1]', :notes
    # See: https://github.com/puppetlabs/puppet-specifications/blob/master/language/func-api.md#experimental--internal-features
    scope_param()
  end

  def compliance_map(map_data, scope)
    create_compliance_map(scope, [map_data])
  end

  def compliance_map_inline(compliance_profile, identifiers, notes=nil, scope)
    args = [compliance_profile, identifiers]

    args << notes if notes

    create_compliance_map(scope, args)
  end

  private

  def create_compliance_map(scope, args)
    #
    # Dynamic per-environment code loader.
    #
    # TODO:
    #   This is persisted into the catalog ONLY to support compliance report
    #   custom entries.
    #
    #   See the compliance_map.rb source code, but these may not be necessary.
    #   If that functionality is removed, return this logic to being
    #   instantiated each time.
    catalog = closure_scope.find_global_scope.catalog

    compliance_report_generator = catalog.instance_variable_get(:@simp_compliance_report_generator)

    unless compliance_report_generator
      object = Object.new()

      filename = File.join(File.dirname(__FILE__), '..', '..', '..', 'puppetx', 'simp', 'compliance_map.rb')
      object.instance_eval(File.read(filename), filename)

      filename = File.join(File.dirname(__FILE__), '..', '..', '..', 'puppetx', 'simp', 'compliance_mapper.rb')
      object.instance_eval(File.read(filename), filename)

      catalog.instance_variable_set(:@simp_compliance_report_generator, object)
      compliance_report_generator = catalog.instance_variable_get(:@simp_compliance_report_generator)
    end

    compliance_report_generator.compliance_map(args, scope)
  end
end
