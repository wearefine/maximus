# Maximus

A warrior for the Colosseum. Sends messages through Mercury.

Plays nice with Middleman and Rails.

In the development block:

`gem 'maximus', git: 'git@bitbucket.org:wearefine/maximus.git'`

## All tasks

First arg (dev mode): Send results to Colosseum if false)
Second arg (path): Custom path to target folder, but don't 

Example:

`rake maximus:fe:scsslint[false,path/to/scss_folder]`

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
