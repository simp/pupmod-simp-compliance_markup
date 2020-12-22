# @summary A wrapper to ensure that the mapper is called during the appropriate
# phase of the catalog compile.
#
# Defines appear to be run after all classes
#
#
# @param options
#   The options hash is passed directly to the `compliance_markup::compliance_map()` function
#
define compliance_markup::map (
  Hash $options = {}
) {
  compliance_markup::compliance_map($options)
}
