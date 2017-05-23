# A wrapper to ensure that the mapper is called during the appropriate phase of the catalog compile.
#
# Defines appear to be run after all classes
#
# The options hash is passed directly to the `compliance_map` function
define compliance_markup::map (
  $options = {}
) {
  compliance_map($options)
}

