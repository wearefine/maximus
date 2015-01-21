# Maximus

[![Gem Version](https://badge.fury.io/rb/maximus.svg)](http://badge.fury.io/rb/maximus) [![Code Climate](https://codeclimate.com/github/wearefine/maximus/badges/gpa.svg)](https://codeclimate.com/github/wearefine/maximus) [![Build Status](https://travis-ci.org/wearefine/maximus.svg)](https://travis-ci.org/wearefine/maximus) [![Inline docs](http://inch-ci.org/github/wearefine/maximus.svg?branch=master&style=flat)](http://inch-ci.org/github/wearefine/maximus)

The all-in-one linting solution.

Plays nice with Middleman and Rails.

## Install

* Gemfile: `gem 'maximus', group: :development`
* Elsewhere/command line: `gem install maximus`
* Globally with RVM (~/.rvm/gemsets/global.gems): `maximus` 

Maximus has several node dependencies that can be installed via the command line:

```bash
$ npm install -g jshint phantomas stylestats
```

or once the gem is successfully installed:

```bash
$ maximus install
```

## Config

Lints and statistics can be configured turned on or off with a  `maximus.yml` file in the root directory maximus is being called in. `config/maximus.yml` will be checked if a config file isn't found in the root, and if there's still no luck, [the default config](lib/maximus/config/maximus.yml) will be loaded.

Parent options are identical to the [command line flags](#flags) with the exception of `include` and `exclude`.

```yaml
domain: 'http://localhost'
port: 3000
paths:
  home: '/'
```

Configs for each lint or statistic are identical to their own syntax.

```yaml
scsslint:
  linters:
    Compass::*:
      enabled: true
```

For systems that are JavaScript based, like JSHint, the YAML is converted to JSON.

```yaml
jshint:
  browser: true
  unused: true
  jquery: true
```

Some configs can be massive and it's more readable to break these into their own files. They can be loaded by setting the value to the path of the desired config.

```yaml
rubocop: 'config/rubocop.yml'
```

Systems and groups of systems can be disabled with booleans. Groups of systems override individual preferences.

```yaml
brakeman: false
statistics: false # no statistics will run
lints: true # all lints including brakeman will run
```

### [Sample Config](lib/maximus/config/maximus-example.yml)

## Command Line

### Flags

Flag                | Accepts                          | Description
--------------------|----------------------------------|--------------------
`-g`/`--sha`      | String                           | Run maximus based on a git commit. See [below](#git-examples)
`-f`/`--frontend`   | Boolean/Blank                    | Run all front-end lints
`-b`/`--backend`    | Boolean/Blank                    | Run all back-end lints
`-s`/`--statistics` | Boolean/Blank                    | Run all statistics
`-a`/`--all`        | Boolean/Blank                    | Run everything
`-i`/`--include`    | String/Array                     | Include specific lints or statistics
`-i`/`--exclude`    | String/Array                     | Exclude specific lints or statistics
`-c`/`--config`     | String                           | Path to config file
`-fp`/`--filepaths` | String/Array                     | Space-separated path(s) to files
`-u`/`--urls`       | String/Array                     | Statistics only - Space-separated path(s) to relative URLs
`-d`/`--domain`     | String                           | Statistics only - Web address (prepended to paths)
`-po`/`--port`      | String/Numeric                   | Statistics only - Port to use if required (appended to domain)


* Lint tasks can accept glob notation, i.e. `**/*.scss`
* Arrays are space-separated, i.e. `--urls=/ /about`

### Commands

Command               | Description
----------------------|---------------------------
`install`             | Installs node dependencies
`frontend`            | Runs all front-end lints
`backend`             | Runs all back-end lints
`statistics`          | Runs all statistics

### Git Examples

`$ maximus -g working` 

Default. Lints based on your working directory

`$ maximus -g last` 

Lints based on the previous commit by `HEAD^`

`$ maximus -g master`

Lints based on the commit on the master branch

`$ maximus -g d96a8e23`

Lints based on commit d96a8e23

## Lint syntax

When adding new lints, the JSON output should obey the following format:

```
[ <filename String>: {
  linter: <test_name String>
  severity: <warning | error | convention | refactor String>
  reason: <explaination String>
  column: <position Integer>
  line: <position Integer>
} ]
```

## Notes

If calling Maximus::Wraith from a script, please see the note in lib/statistics/wraith.rb#result

## Changelog

### 0.1.5

Bugfixes:

* Wraith outputs percentages properly
* Diff data for initial commits
* More intuitive config path discovery
* Flip GitControl#diff around for old to new comparison
* More stability/defensive programming in Config, Wraith, and GitControl

Features:

* Wraith includes images in output

### 0.1.4 (January 3, 2015)

Bugfixes:

* Added basic tests
* Modified git-lines to show unified=1 instead of unified=0
* Remove tmp files error
* Better documentation to README

### 0.1.3 (December 22, 2014)

Features:

* Options are defined once in Config class
* `maximus.yml` can be loaded to set the config
* All lint and statistic options can be in the maximus config file
* More command line flags

### 0.1.2 (December 18, 2014)

Features: 

* Better inline documentation

Bugfixes:

* Resolve exiting error when no lint errors are preset (0efef67)

### 0.1.1 (December 9, 2014)

* Description and homepage update

### 0.1.0 (December 9, 2014)

* Initial


