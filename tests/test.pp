
$value = lookup("test", { "default_value" => "manifest" })
notify { "${value}": }
