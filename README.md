# Maximus

A warrior for the Colosseum. Sends messages through Mercury.

Plays nice with Middleman and Rails.

In the development block:

`gem 'maximus', git: 'git@bitbucket.org:wearefine/maximus.git'`

Lint syntax:

```
[ <filename String>: {
  linter: <test_name String>
  severity: <warning | error | convention | refactor String>
  reason: <explaination String>
  column: <position Integer>
  line: <position Integer>
} ]
```

## All tasks

First arg: Display results in the console and don't send to the Colosseum
Second arg: Custom path to target folder

Example:

`rake maximus:fe:scss[true,path/to/scss_folder]`

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
