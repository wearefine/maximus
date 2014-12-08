# Maximus

A command-line warrior for the [Colosseum](https://bitbucket.org/wearefine/colosseum).

Plays nice with Middleman and Rails.

In the development block:

`gem 'maximus', git: 'git@bitbucket.org:wearefine/maximus.git'`

## Command Line Flags

Flag                | Accepts                          | Description
--------------------|----------------------------------|--------------------
`-p`/`--path`       | String/Array                     | Absolute path to URLs or files
`-f`/`--frontend`   | Boolean/Blank                    | Run all front-end lints
`-b`/`--backend`    | Boolean/Blank                    | Run all back-end lints
`-s`/`--statistics` | Boolean/Blank                    | Run all back-end lints
`-a`/`--all`        | Boolean/Blank                    | Run all everything
`-i`/`--include`    | String/Array                     | Include specific lints or statistics
`-i`/`--exclude`    | String/Array                     | Exclude specific lints or statistics
`-c`/`--commit`     | String/`working`/`last`/`master` |

* Lint tasks can accept glob notation, i.e. `**/*.scss`
* Arrays are space-separated, i.e. `--path=http://localhost:3000/ http://localhost:3000/about`

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
