# This should be called *before* any classes upon which you wish to enforce
# policies
#
# @param profiles
#   Compliance profile names that you wish to enforce
#
#   * Must be present in a compliance map
#
class compliance_markup::test (
  $testvariable = 'none',
){
  notify { 'compliance_markup::test':
    message => "compliance_markup::test::testvariable = ${testvariable}",
  }
}
