# AGENTS.md

This file provides guidance to AI agents when working with code in this repository.

## What this module does

> **Note:** This module is the *original* implementation of the SIMP Compliance
> Engine. It has been superseded by
> [`compliance_engine`](https://github.com/simp/rubygem-simp-compliance_engine),
> which is available both as a standalone Ruby gem and as a Puppet module
> ([`simp-compliance_engine`](https://forge.puppet.com/modules/simp/compliance_engine)
> on the Puppet Forge).

`pupmod-simp-compliance_markup` is the SIMP **Compliance Engine** module. Unlike
most SIMP modules it installs no packages and manages no services — it is almost
entirely Ruby that plugs into Puppet in two ways:

1. **Reporting/validation** — a `compliance_markup::compliance_map()` Puppet
   function that walks the *standing catalog*, compares each in-scope class
   parameter against a set of *compliant* reference values, and writes a
   compliance **report** (JSON/YAML) to the Puppet server and/or the client.
2. **Enforcement** — a `compliance_markup::enforcement` **Hiera 5 `lookup_key`
   backend** that, when a node opts into one or more profiles, *supplies* the
   compliant values as ordinary Hiera lookups, so class parameters default to
   their policy-compliant values without any code changes.

Both halves consume the same **SIMP Compliance Engine (SCE) v2 data**: YAML/JSON
files under `SIMP/compliance_profiles/` (or `simp/compliance_profiles/`) in *any
module on the modulepath*, keyed into `profiles`, `checks`, `ce` (configuration
elements), and `controls`.

## Business logic

### The shared mapper (the unusual core)

`lib/puppetx/simp/compliance_mapper.rb` holds the engine, but it is **not** a
class you instantiate. Callers `instance_eval` the file by absolute path (see
`lib/puppet/functions/compliance_markup/enforcement.rb` and `compliance_map.rb`)
to graft the methods onto themselves, then supply a small callback API the mapper depends on:

- `debug(message)`, `cache(k,v)` / `cached_value(k)` / `cache_has_key(k)` (the
  Hiera backend maps these onto the `Puppet::LookupContext`; other callers stub
  them),
- `lookup` (passed in as the `&block` — abstracts `call_function('lookup', …)`),
- `lookup_fact(fact)`, `module_list`, `codebase`, `environment`.

This lets the identical compilation logic run inside the Hiera backend function
(with real caching/`context.not_found`) and inside the report generator (with
no-op debug/cache) without duplicating it. **When editing the mapper, remember
every method must work for all callers — do not assume the LookupContext exists.**

Key methods in the mapper:

- **`enforcement(key, context, options, &block)`** — the Hiera-backend entry
  point. Immediately `throw :no_such_key` for keys it must not handle
  (`compliance_markup::*` except `debug::`, plus `lookup_options` /
  `compliance_map`) — this is both a filter and the **recursion guard**, backed
  by the `_simp_compliance_markup_lock` cache flag. It looks up
  `compliance_markup::enforcement` (the profile list) and, if non-empty, builds
  the profile map once, caches it per-profile-hash, and returns the requested
  key's compliant value (honoring the `--` knockout prefix).
- **`compiler_class` / `v2_compiler`** — loads every `*.{yaml,json}` under the
  `SIMP/compliance_profiles` load-paths across all module roots (plus
  `HIERA_compliance_data_dir` / `options[:data_dirs]` / `options[:aux_paths]`
  overrides), keeps only files whose top-level `version` parses as SemVer major
  **2**, and deep-merges their `profiles`/`controls`/`checks`/`ce` sections
  (knockout prefix `--`).
- **`apply_confinement`** — drops any check/ce whose `confine` block does not
  match the node: by `module_name` (+ optional `module_version` SemVer range) or
  by arbitrary fact (`!`-prefixed values negate; arrays are OR). Also applies
  `remediation` **risk gating** against `enforcement_tolerance_level` (a check
  disabled or whose risk `level` meets/exceeds the tolerance is dropped).
- **`check_map` / `list_puppet_params(profile_list)`** — resolves a profile's
  selected `checks`/`controls`/`ces` down to a flat
  `parameter => {value, controls, identifiers, oval-ids}` hash. Only checks with
  `type` `puppet`/`puppet-class-parameter` **and** a `settings.parameter` +
  `settings.value` become parameters. When multiple specs set the same
  parameter, values are **merged in profile order** (Arrays concatenated+uniq'd,
  Hashes deep-merged, scalars overwritten); a type mismatch raises.

### The Puppet functions (`lib/puppet/functions/compliance_markup/`)

- **`enforcement.rb`** — thin Hiera 5 backend wrapper. `instance_eval`s the
  mapper, maps the callback API onto `Puppet::LookupContext`, dups the frozen
  `options`, calls `enforcement(...)`, and un-escapes `\--` → `--` in the
  result. `lookup_fact` digs into `$facts`; `module_list` reads env module
  metadata (used by confinement).
- **`compliance_map.rb`** — the **reporting** function (a
  `Puppet::Functions::InternalFunction`). Two dispatches: a full-config `Hash`
  call, or an inline **custom-entry** call
  `compliance_map(profile, identifiers[, notes])`. It lazily builds a report
  generator object (instance_eval'ing both `compliance_map.rb` **and** the
  mapper) and stashes it on the catalog (`@simp_compliance_report_generator`) so
  repeated calls reuse it.
- **`loaded_maps.rb`** — debugging helper; returns the filenames of all loaded
  compliance-data files.

### The report generator (`lib/puppetx/simp/compliance_map.rb`)

`compliance_map(args, context)` compiles the profile map (via the shared mapper),
then for each profile in scope walks `list_puppet_params` and, for each mapped
parameter, finds the corresponding catalog resource and compares the **system
value** to the **compliant value**:

- comparison is `==`, except a compliant value of the form `re:REGEX` is matched
  as a Ruby regex against the stringified system value;
- results are bucketed into `compliant` / `non_compliant`, with
  `documented_missing_parameters` (mapped but absent from the catalog) and
  `documented_missing_resources` collected too;
- `report_types` (`full`, `non_compliant`, `compliant`, `unknown_resources`,
  `unknown_parameters`, `custom_entries`) select which buckets land in the
  report; `full` expands to all of them.

The report (plus `fqdn`/`hostname`/`ip`/`puppetserver_info` and any `site_data`)
is written under `server_report_dir/<fqdn>/compliance_report.<fmt>` on the
server and, if `client_report`, added as a `0600 File` resource on the client
(so it flows into PuppetDB). `catalog_to_compliance_map` additionally dumps a
generated map of *every* catalog resource parameter (experimental).

Profiles for the *report* are discovered (in order) from the global
`$compliance_profile`, the global `$compliance_markup::validate_profiles`, or the
`compliance_markup` class's `validate_profiles` parameter.

### The manifests

- **`manifests/init.pp`** (`compliance_markup` class) — pure configuration
  front-end for the report. It assembles an `options` hash from its parameters
  (`report_types`, `report_format`, `report_on_client`/`_server`,
  `server_report_dir`, `custom_report_data`, or a raw `options` passthrough) and
  declares `compliance_markup::map { 'execute': }`. **Include it *after* every
  other class** (e.g. last line of `site.pp`) so the catalog is complete when it
  runs.
- **`manifests/map.pp`** (`compliance_markup::map` define) — a one-line wrapper
  that calls the function. It exists **because defines evaluate after classes**,
  which is what guarantees the report runs against the fully-populated catalog.

## Dependencies

- `puppetlabs/stdlib` (`>= 8.0.0 < 10.0.0`) — the client report needs the
  `puppet_vardir` fact.
- `simp/simplib` (`>= 4.9.0 < 5.0.0`).
- Ruby `deep_merge` and `semantic_puppet` (the latter shipped with Puppet) are
  `require`d by the mapper.
- Runtime: `puppet >= 7.0.0 < 9.0.0`. Supported OS: EL7/8/9 (RedHat/CentOS/
  OracleLinux), EL8/9 (Rocky/AlmaLinux), Amazon 2 (see `metadata.json`).

## Repository layout

- `lib/puppetx/simp/compliance_mapper.rb` — **the engine**: `enforcement()`, the
  v2 data compiler, confinement, and parameter resolution (shared, instance_eval'd).
- `lib/puppetx/simp/compliance_map.rb` — the report generator (shared, instance_eval'd).
- `lib/puppet/functions/compliance_markup/{enforcement,compliance_map,loaded_maps}.rb`
  — the Hiera backend, the reporting function, and the debug helper.
- `manifests/init.pp` — `compliance_markup` class (report config front-end).
- `manifests/map.pp` — `compliance_markup::map` define (runs the function post-classes).
- `data/common.yaml` + `hiera.yaml` — module data: the empty
  `compliance_markup::compliance_map` default and its deep-merge/`--` knockout
  `lookup_options`.
- `SIMP/compliance_profiles/` — **example** shipped SCE v2 data (`checks.yaml`,
  `profile-disa_stig.yaml`, `profile-nist_800_53_rev4.yaml`).
- `utils/` — migration/conversion helpers (v1→v2 import, JSON↔YAML, the
  `compliance_map_migrate` script, `master-controls.yaml`).
- `spec/functions/compliance_markup/` — the bulk of the tests: enforcement,
  confinement, merge, profile-merge, override, debug, and enforce specs.
- `spec/classes/init_spec.rb`, `spec/unit/…`, `spec/acceptance/suites/default/`
  (beaker) — class, unit, and acceptance tests.
- `REFERENCE.md` — generated Puppet Strings reference (do not hand-edit; regenerate).
- `metadata.json` — module metadata, dependencies, supported OS matrix.

## Common commands

This module uses `puppetlabs_spec_helper` + `simp-rake-helpers (~> 5)` +
`simp-beaker-helpers (~> 2)`; tasks come from `Simp::Rake::Pupmod::Helpers`
(see `Rakefile`).

```sh
bundle install

# Unit tests (rspec-puppet + the Ruby function specs)
bundle exec rake spec

# A single spec file (note: .rspec sets --fail-fast)
bundle exec rspec spec/functions/compliance_markup/00_enforcement_spec.rb

# Lint / style
bundle exec rake lint
bundle exec rake rubocop

# Regenerate REFERENCE.md after changing manifest/function docstrings
bundle exec puppet strings generate --format markdown --out REFERENCE.md

# Acceptance tests (beaker; needs a hypervisor)
bundle exec rake beaker:suites[default]
```

## Conventions

- This is a component of the SIMP ecosystem; follow SIMP module conventions.
- The engine deliberately lives in `instance_eval`'d shared files so the Hiera
  backend and the report generator share one implementation. Keep new mapper
  methods callable by **all** callers — never assume a `Puppet::LookupContext`,
  and route logging through the caller's `debug`.
- Only **v2** compliance data (top-level `version:` with SemVer major `2`) is
  compiled; other files are silently ignored. Preserve that gate.
- `--` is the deep-merge **knockout prefix** throughout (module data,
  profile/check/ce merges, and enforcement output). A literal `--` in real data
  must be escaped as `\--`; the backend un-escapes it on the way out. Don't break
  this round-trip.
- Enforcement must never recurse into its own keys: keep the early
  `throw :no_such_key` filter and the `_simp_compliance_markup_lock` guard intact.
- `compliance_markup` must be evaluated last (it reports on the standing
  catalog); the `compliance_markup::map` define exists solely to enforce that
  ordering — don't fold it back into the class.
- Keep manifest/function `@param` docstrings current — `REFERENCE.md` is
  generated from them.
