# This should be called *before* any classes upon which you wish to enforce
# policies
#
# @param profiles
#   Compliance profile names that you wish to enforce
#
#   * Must be present in a compliance map
#
class compliance_markup::enforcement_helper (
  Optional[Array[String[1]]] $profiles = undef
){
  include ::compliance_markup
}
