# Maximus

A warrior for the Colosseum.

Plays nice with Middleman and Rails.

In the development block:

`gem 'maximus', git: 'git@bitbucket.org:wearefine/maximus.git'`

Lint syntax:

```
<filename>: {
  linter: <test_name String>
  severity: <warning | error | convention | refactor String>
  reason: <explaination String>
  column: <position Integer>
  line: <position Integer>
}
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

`rake maximus:fe:stylestats`

## Back End tasks

`rake maximus:be`

### Rubocop

`rake maximus:be:rb`