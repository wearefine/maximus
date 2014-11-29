# Maximus

A warrior for the [Colosseum](https://bitbucket.org/wearefine/colosseum).

Plays nice with Middleman and Rails.

In the development block:

`gem 'maximus', git: 'git@bitbucket.org:wearefine/maximus.git'`

## All tasks

First and only arg (path): Path to target folder/file or URL if using Phantomas.
Lint tasks can accept glob notation, i.e. `**/*.scss`
Statistics tasks can accept an Array

Example:

`rake maximus:fe:scsslint[app/assets/stylesheets]`

## Front End tasks

`rake maximus:fe`

### SCSS Lint

`rake maximus:fe:scsslint`

### JSHint

`rake maximus:fe:jshint`

## Back End tasks

`rake maximus:be`

### Rubocop

`rake maximus:be:rubocop`

### Rails Best Practices

`rake maximus:be:railsbp`

### Brakeman

`rake maximus:be:brakeman`

## Statistics

### Stylestats

`rake maximus:stat:stylestats`

### Phantomas

`rake maximus:stat:phantomas`

## Lint committed files against the master branch with git

`rake maximus:compare`

## Front End, Back End, Stats, Compare

`rake maximus`

## Lint syntax:

```
[ <filename String>: {
  linter: <test_name String>
  severity: <warning | error | convention | refactor String>
  reason: <explaination String>
  column: <position Integer>
  line: <position Integer>
} ]
```
