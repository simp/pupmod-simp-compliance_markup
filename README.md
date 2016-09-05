[![License](http://img.shields.io/:license-apache-blue.svg)](http://www.apache.org/licenses/LICENSE-2.0.html) [![Build Status](https://travis-ci.org/simp/pupmod-simp-compliance_markup.svg)](https://travis-ci.org/simp/pupmod-simp-compliance_markup)

#### Table of Contents

1. [Overview](#overview)
2. [Upgrading](#upgrading)
3. [Module Description - What the module does and why it is useful](#module-description)
4. [Setup - The basics of getting started with compliance_markup](#setup)
    * [What compliance_markup affects](#what-compliance_markup-affects)
    * [Setup requirements](#setup-requirements)
    * [Beginning with compliance_markup](#beginning-with-compliance_markup)
5. [Usage - Configuration options and additional functionality](#usage)
6. [Reference - An under-the-hood peek at what the module is doing and how](#reference)
7. [Limitations - OS compatibility, etc.](#limitations)
8. [Development - Guide for contributing to the module](#development)
      * [Acceptance Tests - Beaker env variables](#acceptance-tests)

## Overview

This module adds a function `compliance_map()` to the Puppet language. The
`compliance_map()` function provides the ability for users to compare their
in-scope class parameters against a set of *compliant* parameters, either in
Hiera or at the global scope. Users may also provide custom inline policy
documentation and mapping documentation.

The goal of this module is to make it easier for users to both detect, and
report on, deviations from a given policy inside their Puppet codebase.

## Module Description

This module provides the function `compliance_map()` and a `compliance_markup`
class for including the functionality into your stack at the global level.

A utility for converting your old `compliance_map()` Hiera data has also been
included in the `utils` directory.

## Upgrading

A utility script, `compliance_map_migrate` has been included in the `utils`
directory of the module to upgrade your old compliance data to newer formats.

Please validate that the migrated YAML files work as expected prior to
deploying them into production.

## Setup

### What compliance_markup affects

By default, the `compliance_map()` function creates a set of reports, one per
node, on your Puppet Server at
`Puppet[:vardir]/simp/compliance_reports/<fqdn>`.

You may optionally enable the creation of a `File` resource on each of your
clients if you with to have changes in this data automatically exported into
`PuppetDB`.

## Usage

The `compliance_map()` function provides a mechanism for mapping compliance
data to settings in Puppet and should be globally activated by `including` the
`compliance_markup` class.

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
        'identifier' : 'ID String'
        'value'      : 'Compliant Value'
        'notes'      : 'Optional Notes'
```

For instance, if you were mapping to `NIST 800-53` in the `SSH` class, you
would use something like the following:

```
  compliance_map :
    nist_800_53 :
      ssh::permit_root_login :
        'identifier' : 'CCE-1234'
        'value'      : false
```

Alternatively, you may use the `compliance_map()` function to add compliance
data to your modules outside of a parameter mapping. This is useful if you have
more advanced logic that is required to meet a particular internal requirement.

**NOTE:** The parser does not know what line number and, possibly, what file
the function is being called from based on the version of the Puppet parser
being used.

The following parameters may be used to add your own compliance data:

```ruby
:compliance_profile => 'A String, or Array, that denotes the compliance
                        profile(s) to which you are mapping.'
:identifier         => 'A unique identifier String for the policy to which you
                        are mapping.'
:notes              => 'An *optional* String that allows for arbitrary notes to
                        include in the compliance report'
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
  * *custom_entries*: Any one-off custom calls to compliance_map will be
  reported.

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

## Reference

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
  "compliance_profiles/%{compliance_profile}"
  "global"
```

**Hieradata**

```yaml
---
# In file /path/to/your/hieradata/compliance_profiles/my_policy.yaml
compliance_map :
  my_policy :
    foo::var_one :
      'identifier' : 'POLICY_SECTION_ID'
      'value' : 'one'
```

### Example 2 - Custom Compliance Map

```ruby
if $::circumstance {
  compliance_map('my_policy','POLICY_SECTION_ID','Note about this section')
  ...code that applies POLICY_SECTION_ID...
}
```

## Limitations

Depending on the version of Puppet being used, the `compliance_map()` function
may not be able to precisely determine where the function has been called and a
best guess may be provided.

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
