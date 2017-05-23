# This class should be called as the *last* item in your catalog to perform
# environment validation
#
# Set parameters in the ``compliance_markup`` class to affect the action of the
# validator
#
# This class cannot be automatically included due to compile time ordering
class compliance_markup::validate {
  include ::compliance_markup

  compliance_markup::map { 'execute': options => $::compliance_markup::_options }
}

