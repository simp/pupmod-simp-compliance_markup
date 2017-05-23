# The compliance markup helper class
#
# This class should be included *after* all other classes in your site so that
# the mapper can properly analyze the standing catalog.
#
# @param validate_profiles
#   Compliance profiles that you wish to validate against
#
# @param compliance_map
#   The compliance Hash to which to map
#
#   * This defaults to data in modules
#
# @param report_types
#   The types of entries that you want to report on
#
#   * full               => Include all report types*
#   * non_compliant      => Report on non-compliant parameters*
#   * unknown_parameters => Report on parameters that are mapped but not included in the catalog*
#   * custom_entries     => Report custom calls to compliance_map() from the codebase
#   * compliant          => Report on compliant parameters
#   * unknown_resources  => Report on classes that are mapped but not included in the catalog
#
#   * This is ignored if ``options`` is specified
#
# @param report_format
#   The output format for the report
#
# @param report_on_client
#   Save a copy of the report on the client as a ``File`` resource
#
#   * This will make the report show up in PuppetDB but may also expose
#     unwanted vulnerability information
#
# @param report_on_server
#   Save a copy of the report on the puppet server
#
# @param server_report_dir
#   The path where the server should store reports
#
#   * If you change this, you must make sure that the puppet *server* can write
#     to the location.
#   * By default, this is written to ``Puppet[:vardir]`` as the Puppet *server*
#     sees it:
#     ``/opt/puppetlabs/server/data/puppetserver/simp/compliance_reports``
#
# @param custom_report_entries
#   A hash that will be included in the compliance report under the heading
#   ``site_data``
#
#   * This can be used for adding *anything* to the compliance report. The hash
#     is simply processed with ``to_yaml``
#
# @param options
#   The options to pass directly to the `compliance_map` validation function
#
#   * If specified, various other options may be ignored
class compliance_markup (
  Optional[Array[String[1]]]     $validate_profiles     = undef,
  Hash                           $compliance_map        = {},
  Array[
    Enum[
      'full',
      'non_compliant',
      'compliant',
      'unknown_resources',
      'unknown_parameters',
      'custom_entries'
    ]
  ]                              $report_types       = ['non_compliant', 'unknown_parameters', 'custom_entries'],
  Enum['json','yaml']            $report_format      = 'json',
  Boolean                        $report_on_client   = false,
  Boolean                        $report_on_server   = true,
  Optional[Stdlib::Absolutepath] $server_report_dir  = undef,
  Optional[Hash]                 $custom_report_data = undef,
  Optional[Hash]                 $options            = undef
) {
  $available_profiles = delete($compliance_map.keys, 'version')

  if $options {
    if $compliance_map and !$options['default_map'] {
      $_full_options = $options + { 'default_map' => $compliance_map }
    }
    else {
      $_full_options = $options
    }

    $_options = $_full_options
  }
  else {
    $_options = {
      'report_types'      => $report_types,
      'format'            => $report_format,
      'client_report'     => $report_on_client,
      'server_report'     => $report_on_server,
      'server_report_dir' => $server_report_dir,
      'site_data'         => $custom_report_data
    }
  }
}
