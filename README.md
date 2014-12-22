# Maximus

[![Gem Version](https://badge.fury.io/rb/maximus.svg)](http://badge.fury.io/rb/maximus) [![Code Climate](https://codeclimate.com/github/wearefine/maximus/badges/gpa.svg)](https://codeclimate.com/github/wearefine/maximus)

The all-in-one linting solution.

Plays nice with Middleman and Rails.

## Install

* Gemfile: `gem 'maximus', group: :development`
* Elsewhere/command line: `gem install maximus`
* Globally with RVM (~/.rvm/gemsets/global.gems): `maximus` 

Maximus has several node dependencies that can be installed with a `npm install -g jshint phantomas stylestats` or a `maximus install` once the gem is successfully installed.

## Command Line Flags

Flag                | Accepts                          | Description
--------------------|----------------------------------|--------------------
`-fp`/`--filepaths` | String/Array                     | Space-separated path(s) to files
`-u`/`--urls`       | String/Array                     | Statistics only - Space-separated path(s) to relative URL paths
`-d`/`--domain`     | String                           | Statistics only - Web address (prepended to paths)
`-po`/`--port`      | String/Numeric                   | Statistics only - Port to use if required (appended to domain)
`-f`/`--frontend`   | Boolean/Blank                    | Run all front-end lints
`-b`/`--backend`    | Boolean/Blank                    | Run all back-end lints
`-s`/`--statistics` | Boolean/Blank                    | Run all statistics
`-a`/`--all`        | Boolean/Blank                    | Run everything
`-i`/`--include`    | String/Array                     | Include specific lints or statistics
`-i`/`--exclude`    | String/Array                     | Exclude specific lints or statistics
`-git`/`--sha`      | String/`working`/`last`/`master` | Run maximus based on a git commit or your working copy
`-c`/`--config`     | String                           | Path to config file


* Lint tasks can accept glob notation, i.e. `**/*.scss`
* Arrays are space-separated, i.e. `--urls=/ /about`

## Command Line Commands

Command               | Description
----------------------|---------------------------
`install`             | Installs node dependencies
`frontend`            | Runs all front-end lints
`backend`             | Runs all back-end lints
`statistics`          | Runs all statistics

## Examples

Default. Lints based on your working directory

`maximus -c working` 

Lints based on the previous commit by `HEAD^`

`maximus -c last` 

Lints based on the commit on the master branch

`maximus -c master`

Lints based on commit d96a8e23

`maximus -c d96a8e23`

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

## Changelog

### 0.1.3

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


