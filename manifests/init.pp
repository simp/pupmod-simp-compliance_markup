class compliance_markup (
  $options = {}
) {
  ::compliance_markup::map { 'execute':
    options => $options
  }
}
