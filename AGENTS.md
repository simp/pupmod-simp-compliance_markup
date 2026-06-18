# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Overview

`pupmod-simp-compliance_markup` (Puppet Forge: `simp/compliance_markup`) is a Puppet
module that does two distinct things:

1. **Reporting** — a `compliance_markup::compliance_map()` function plus the
   `compliance_markup` class that compares in-scope class parameters against
   *compliant* reference values and emits per-node compliance reports.
2. **Enforcement** — a Hiera v5 `lookup_key` backend (the "SIMP Compliance Engine")
   that *injects* compliant parameter values into the catalog by overriding
   `lookup()` results for any class parameter covered by an active profile.

These are largely independent code paths that happen to share data formats and the
`compliance_mapper.rb` codebase.

## Common Commands

This is a PDK/SIMP-style module; everything runs through `bundle exec rake`.

```shell
bundle install

bundle exec rake spec              # all unit/function specs (runs in parallel)
bundle exec rake lint              # puppet-lint
bundle exec rake rubocop           # ruby style
bundle exec rake syntax            # puppet + custom data/ JSON/YAML syntax checks
bundle exec rake validate          # combined validation
bundle exec rake beaker:suites     # acceptance tests (see below)
```

Run a single spec file or example:

```shell
bundle exec rspec spec/functions/compliance_markup/00_enforcement_spec.rb
bundle exec rspec spec/functions/compliance_markup/00_enforcement_spec.rb:42   # by line
```

Note `.rspec` sets `--fail-fast`, so a spec run stops at the first failure.

Acceptance tests use Beaker against Docker nodesets (see `spec/acceptance/nodesets/`).
Select a nodeset with `BEAKER_set`, e.g.:

```shell
BEAKER_set=docker_rocky9 bundle exec rake beaker:suites
```

## Architecture

### Shared mapper core — `lib/puppetx/simp/compliance_mapper.rb`

This file is **not** a normal class. It defines top-level methods (`enforcement`,
`compiler_class`, etc.) that get pulled into a caller via `instance_eval`. Three
callers do this and supply a small adapter API (`debug`, `cache`, `cached_value`,
`cache_has_key`, `environment`, `codebase`, `lookup_fact`, `module_list`):

- `lib/puppet/functions/compliance_markup/enforcement.rb` — the Hiera v5 backend.
- `lib/puppet/functions/compliance_markup/loaded_maps.rb` — debug helper listing loaded files.
- (the reporting function shares the data-loading half of the design)

So when changing `compliance_mapper.rb`, remember it executes inside several
different objects that each provide the methods listed at the top of the file.

`compiler_class` builds an anonymous class at runtime that:
1. Globs every `SIMP/compliance_profiles/**/*.{yaml,json}` (and `simp/...`) under all
   module paths in the environment, plus override dirs from the `data_dirs` /
   `aux_paths` backend options or the `HIERA_compliance_data_dir` env var.
2. Hands version-2.0.0 files to the nested `v2_compiler`, which deep-merges
   `profiles`, `controls`, `ces` (configuration elements), and `checks` (with `--`
   knockout-prefix support).
3. `check_map` / `list_puppet_params` resolve an ordered profile list into a flat
   `parameter => value` map, applying fact-based **confinement** and **enforcement
   tolerance** (risk-level filtering) along the way.

The Hiera backend uses an internal `_simp_compliance_markup_lock` cache flag to
prevent infinite recursion (it calls `lookup()` while answering a `lookup()`), and
caches the whole compiled profile map after the first key is resolved.

### Reporting path — `lib/puppetx/simp/compliance_map.rb`

Separate codebase that walks the compiled catalog (`catalog_to_map`) and produces
the per-node report described in `README.md` (Report Format section). Driven by:
- `manifests/init.pp` (`compliance_markup` class) — collects options, then declares
- `manifests/map.pp` (`compliance_markup::map` define) — a define is used so the
  mapping runs *after* all classes during catalog compilation.

Include `compliance_markup` **last** (e.g. end of `site.pp`) so the full catalog is
visible.

### Data formats

- **v2 engine data** lives in `SIMP/compliance_profiles/*.yaml` with
  `version: 2.0.0` and top-level `profiles` / `controls` / `ces` / `checks` keys.
  See `SIMP/compliance_profiles/checks.yaml` for the canonical check shape
  (`settings.parameter`, `settings.value`, `type: puppet`/`puppet-class-parameter`,
  `controls`, `identifiers`, `oval-ids`, optional `confine` and `remediation.risk`).
- **Legacy reporting data** uses the older `compliance_map: { <profile>: { <class>::<param>: ... } }` Hash.
- `utils/` holds migration/conversion scripts (`compliance_map_migrate`,
  `compliance_profile_{json2yaml,yaml2json}.rb`, `import_from_v1.rb`).

### Enforcement specifics worth knowing

- Profiles are enforced via `compliance_markup::enforcement: [ 'profile_a', 'profile_b' ]`
  in Hiera; earlier entries take priority.
- `compliance_markup::enforcement_tolerance_level` (default 40) gates which checks
  apply based on each check's `remediation.risk.level`.
- Debug keys are real Hiera lookups: `compliance_markup::debug::{dump,profiles,compliance_data,hiera_backend_compile_time}`.
- `--` is the knockout prefix; strings needing a literal `--` are escaped as `\--`
  and un-escaped in `enforcement.rb`.

## Conventions

- `Gemfile`, and other baseline files are **maintained by puppetsync** (see the header
  notice) — local edits get overwritten by the next module-baseline sync.
- Target runtime is OpenVox/Puppet 8 on EL8/9/10 (CentOS/RHEL/Oracle/Rocky/Alma).
- `rake syntax` is extended in `rakelib/syntax.rake` to validate JSON/YAML under `data/`.
