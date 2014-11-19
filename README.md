# Maximus

A warrior for the Colosseum. Sends messages through Mercury.

Plays nice with Middleman and Rails.

In the development block:

`gem 'maximus', git: 'git@bitbucket.org:wearefine/maximus.git'`

## All tasks

First arg (dev mode): Send results to Colosseum if false)
Second arg (path): Custom path to target folder, but don't 

Example:

`rake maximus:fe:scss[false,path/to/scss_folder]`

## Front End tasks

`rake maximus:fe`

### SCSS Lint

`rake maximus:fe:scss`

### JSHint

`rake maximus:fe:js`

### Stylestats

`rake maximus:stat:stylestats`

## Back End tasks

`rake maximus:be`

### Rubocop

`rake maximus:be:rb`

### Rails Best Practices

`rake maximus:be:railsbp`

### Brakeman

`rake maximus:be:brakeman`

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
