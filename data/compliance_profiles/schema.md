# `compliance_markup` data schema

Compliance markup data should follow the schema located next to this document.

Here is an overview:

```json
{
  "compliance_markup::compliance_map::percent_sign": "%",
  "compliance_markup::compliance_map": {
    "version": "1.0.0",
    "compliance_map_name": {
      "puppet::class::parameter": {
        "value": true,
        "identifiers": [
          "CCI-000000",
          "SRG-000",
          "AU-9"
        ]
      }
    }
  }
}
```

## Checking the schema

The data file can be valiated against the schema by running the
`rake schema:validate` rake task, or by the CI system running `rake validate`.

## Details

We're going to skip down to the `compliance_markup::compliance_map` item because
items above that are fairly inconsequential.


### `version`

The version of the compliance engine that the data is intended for

### `compliance_map_name`

Name of the complince standard that is being mapped

#### `puppet::class::parameter`

The fully-namespaced Puppet class parameter, as it would be written if you were
to set it in hiera.

##### `value`

The value that the Puppet parameter should be set to to enforce the compliance
standard.

##### `identifiers`

Compliance standard identifiers that are impacted by this Puppet parameter.

##### `opal-id`

OPAL identifiers that are impacted by this Puppet parameter.

##### `notes`

Notes on this parameter.
