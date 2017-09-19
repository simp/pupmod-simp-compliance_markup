$tvalue = lookup("compliance_markup::test::testvariable", { "default_value" =>  "manifest"})

notify { "compliance_markup::test::testvariable = ${tvalue}": }
$vvalue = lookup("compliance_markup::test::vendoredvariable", { "default_value" =>  "manifest"})

notify { "compliance_markup::test::vendoredvariable = ${vvalue}": }
