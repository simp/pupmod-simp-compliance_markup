[![License](https://img.shields.io/:license-apache-blue.svg)](http://www.apache.org/licenses/LICENSE-2.0.html)
[![CII Best Practices](https://bestpractices.coreinfrastructure.org/projects/73/badge)](https://bestpractices.coreinfrastructure.org/projects/73)
[![Puppet Forge](https://img.shields.io/puppetforge/v/simp/compliance_markup.svg)](https://forge.puppetlabs.com/simp/compliance_markup)
[![Puppet Forge Downloads](https://img.shields.io/puppetforge/dt/simp/compliance_markup.svg)](https://forge.puppetlabs.com/simp/compliance_markup)
[![Build Status](https://travis-ci.org/simp/pupmod-simp-compliance_markup.svg)](https://travis-ci.org/simp/pupmod-simp-compliance_markup)

Table of Contents

<!-- vim-markdown-toc GFM -->

* [Overview](#overview)
* [Module Description](#module-description)
* [Upgrading](#upgrading)
* [Reporting](#reporting)
  * [What compliance_markup affects](#what-compliance_markup-affects)
* [Usage](#usage)
  * [Report Format](#report-format)
  * [Options](#options)
    * [report_types](#report_types)
    * [site_data](#site_data)
    * [client_report](#client_report)
    * [server_report](#server_report)
    * [server_report_dir](#server_report_dir)
    * [server_report_dir](#server_report_dir-1)
    * [catalog_to_compliance_map](#catalog_to_compliance_map)
* [Reference](#reference)
  * [Example 1 - Standard Usage](#example-1---standard-usage)
  * [Example 2 - Custom Compliance Map](#example-2---custom-compliance-map)
* [Enforcement](#enforcement)
  * [v5 Backend Configuration](#v5-backend-configuration)
  * [Configuring profiles to enforce](#configuring-profiles-to-enforce)
* [Limitations](#limitations)
* [Development](#development)
  * [Acceptance tests](#acceptance-tests)
* [Packaging](#packaging)

<!-- vim-markdown-toc -->

## Overview

This module adds a function `compliance_markup::compliance_map()` to the Puppet
language. The `compliance_markup::compliance_map()` function provides the
ability for users to compare their in-scope class parameters against a set of
*compliant* parameters, either in Hiera or at the global scope. Users may also
provide custom inline policy documentation and mapping documentation.

The goal of this module is to make it easier for users to both detect, and
report on, deviations from a given policy inside their Puppet codebase.

See [REFERENCE.md](./REFERENCE.md) for more information.

## Module Description

This module provides the function `compliance_markup::compliance_map()` and a
`compliance_markup` class for including the functionality into your stack at
the global level.

A utility for converting your old `compliance_markup::compliance_map()` Hiera
data has also been included in the `utils` directory.

## Upgrading

A utility script, `compliance_map_migrate` has been included in the `utils`
directory of the module to upgrade your old compliance data to newer formats.

At minimum, you must pass to the script a compliance profile to migrate, the
version of the API it *was* compatible with, and the version you wish to migrate
it to.  For instance, to upgrade a compliance map from API 0.0.1 to 1.0.0:

`ruby compliance_map_migrate -i /etc/puppetlabs/code/environments/simp/hieradata/compliance_profiles/nist_800_53_rev4.yaml  -s 0.0.1 -d 1.0.0`

Please validate that the migrated YAML files work as expected prior to
deploying them into production.

## Reporting

### What compliance_markup affects

By default, the `compliance_markup::compliance_map()` function creates a set of
reports, one per node, on your Puppet Server at
`/opt/puppetlabs/server/data/puppetserver/simp/compliance_reports/<fqdn>`.

You may optionally enable the creation of a `File` resource on each of your
clients if you wish to have changes in this data automatically exported into
`PuppetDB`.

## Usage

The `compliance_markup::compliance_map()` function provides a mechanism for
mapping compliance data to settings in Puppet and should be globally activated
by `including` the `compliance_markup` class.

It is primarily designed for use in classes to validate that parameters are
properly set but may also be used to perform a *full* compliance report against
multiple profiles across your code base at compile time.

When the `compliance_markup` class is included, the parameters in all in-scope
classes and defined types will be evaluated against top level parameters,
`lookup()` values, or Hiera data, in that order.

The variable space against which the parameters will be evaluated must be
structured as the following hash:

```
  compliance_map :
    <compliance_profile> :
      <class_name>::<parameter> :
        'identifiers' :
        - 'ID String'
        'value'      : 'Compliant Value'
        'notes'      : 'Optional Notes'
```

For instance, if you were mapping to `NIST 800-53` in the `SSH` class, you
would use something like the following:

```
  compliance_map :
    nist_800_53 :
      ssh::permit_root_login :
        'identifiers' :
        - 'CCE-1234'
        'value'      : false
```

Alternatively, you may use the `compliance_markup::compliance_map()` function
to add compliance data to your modules outside of a parameter mapping. This is
useful if you have more advanced logic that is required to meet a particular
internal requirement.

**NOTE:** The parser does not know what line number and, possibly, what file
the function is being called from based on the version of the Puppet parser
being used.

The following parameters may be used to add your own compliance data:

```ruby
:compliance_profile => 'A String, or Array, that denotes the compliance
                        profile(s) to which you are mapping.'
:identifiers        => 'An array of identifiers for the policy to which you
                        are mapping.'
:notes              => 'An *optional* String that allows for arbitrary notes to
                        include in the compliance report'
```

### Report Format

The compliance report is formatted as follows (YAML Representation):

```yaml
---
# The API version of the report
version: "1.0.1"
fqdn: "my.system.fqdn"
hostname: "my"
ipaddress: "1.2.3.4"
puppetserver_info: "my.puppet.server"
compliance_profiles:
  profile_name:
    summary:
      compliant: 80
      non_compliant: 20
      percent_compliant: 80
      documented_missing_resources: 2
      documented_missing_parameters: 1

    compliant:
      "Class[ClassName]":
        parameters:
          param1:
            identifiers:
              - ID 1
              - ID 2
            compliant_value: 'foo'
            system_value: 'foo'

    non_compliant:
      "Class[BadClass]":
        parameters:
          bad_param:
            identifiers:
              - ID 3
              - ID 4
            compliant_value: 'bar'
            system_value: 'baz'

    documented_missing_resources:
      - missing_class_one
      - missing_class_two

    documented_missing_parameters:
      - "classname::param2"

    custom_entries
      "Class[CustomClass]":
        location: "file.pp:123"
        identifiers:
          - My ID

site_data:
  completely: random user input
```

### Options

The `compliance_markup` class may take a number of options which must be passed
as a `Hash`.

#### report_types

*Default*: `[ 'non_compliant', 'unknown_parameters', 'custom_entries' ]`

A String, or Array that denotes which types of reports should be generated.

*Valid Types*:
  * *full*: The full report, with all other types included.
  * *non_compliant*: Items that differ from the reference will be reported.
  * *compliant*: Compliant items will be reported.
  * *unknown_resources*: Reference resources without a system value will be
  reported.
  * *unknown_parameters*: Reference parameters without a system value will be
  reported.
  * *custom_entries*: Any one-off custom calls to
    compliance_markup::compliance_map will be
    reported.

#### site_data

*Default*: None

A valid *Hash* that will be converted *as passed* and emitted into your node
compliance report.

This can be used to add site-specific or other information to the report that
may be useful for post-processing.

#### client_report

*Default*: `false`

A Boolean which, if set, will place a copy of the report on the client itself.
This will ensure that PuppetDB will have a copy of the report for later
processing.

#### server_report

*Default*: true

A Boolean which, if set, will store a copy of the report on the Server.

#### server_report_dir

*Default*: `Puppet[:vardir]/simp/compliance_reports`

An Absolute Path that specifies the location on

#### server_report_dir

*Default*: `Puppet[:vardir]/simp/compliance_reports`

An Absolute Path that specifies the location on the *server* where the reports
should be stored.

A directory will be created for each FQDN that has a report.

#### catalog_to_compliance_map

*Default*: false

A Boolean which, if set, will dump a compatible compliance_map of *all*
resources and defines that are in the current catalog.

This will be written to ``server_report_dir/<client_fqdn>`` as ``catalog_compliance_map``.
Old versions will be overwritten.

NOTE: This is an experimental feature and subject to change without notice.

## Reference

The full module reference can be found in the
[module docs](https://simp.github.io/pupmod-simp-compliance_markup) and in the
local `docs/` directory.

### Example 1 - Standard Usage

**Manifest**

```ruby
class foo (
  $var_one => 'one',
  $var_two => 'two'
) {
  notify { 'Sample Class': }
}

$compliance_profile = 'my_policy'

include '::foo'
include '::compliance_markup'
```

**Hiera.yaml**

```yaml
:backends:
  - 'yaml'
:yaml:
  :datadir: '/path/to/your/hieradata'
:hierarchy:
  "global"
```

**Hieradata**

```yaml
---
# In file /path/to/your/hieradata/global.yaml
compliance_map :
  my_policy :
    foo::var_one :
      'identifiers' :
      - 'POLICY_SECTION_ID'
      'value' : 'one'
```

### Example 2 - Custom Compliance Map

```ruby
if $::circumstance {
  compliance_markup::compliance_map('my_policy','POLICY_SECTION_ID','Note about this section')
  ...code that applies POLICY_SECTION_ID...
}
```

## Enforcement

This module also contains a Hiera backend that can be used to enforce compliance
profile settings on any module when it is included. It uses the
`compliance_markup::enforcement` Array to determine the profiles to use, and
which profiles take priority.

Only a Hiera v5 backend is provided. Because of this, the Hiera backend is only
available on versions of Puppet 4.10 or above.


### v5 Backend Configuration

```yaml
---
version: 5
hierarchy:
  - name: SIMP Compliance Engine
    lookup_key: compliance_markup::enforcement
    # All options are optional
    options:
      # Ignore all default data dirs and use these instead
      data_dirs:
        - /fully/qualified/data_dir
  - name: Common
    path: default.yaml
defaults:
  data_hash: yaml_data
  datadir: "/etc/puppetlabs/code/environments/production/hieradata"

```


### Configuring profiles to enforce

To enforce disa stig + nist, with disa stig compliance settings taking priority,
add the following to your hiera data files. This will work like any hiera setting,
so you can set enforcement based on any factor, including host, hostgroup, kernel
or specfic os version.

```yaml
---
compliance_markup::enforcement: [ 'disa_stig', 'nist_800_53_rev4' ]
```

## Limitations

Depending on the version of Puppet being used, the
`compliance_markup::compliance_map()` function may not be able to precisely
determine where the function has been called and a best guess may be provided.

Hash values for Puppet parameters in compliance data will always be deep
merged. Configurable merge behavior may be implemented in a future release.

## Development

Patches are welcome to the code on the [SIMP Project Github](https://github.com/simp/pupmod-simp-compliance_markup) account. If you provide code, you are
guaranteeing that you own the rights for the code or you have been given rights
to contribute the code.

### Acceptance tests

To run the tests for this module perform the following actions after installing
`bundler`:

```shell
bundle update
bundle exec rake spec
bundle exec rake beaker:suites
```

## Packaging

Running `rake pkg:rpm[...]` will develop an RPM that is designed to be
integrated into a [SIMP](https://github.com/simp) environment. This module is
not restricted to, or dependent on, the SIMP environment in any way.
