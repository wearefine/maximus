#!/usr/bin/env node
/* jshint node: true */

"use strict";

var deps_available = true;

var sys = require('sys')
var exec = require('child_process').exec;
var child;
var deps = ['stylestats', 'jshint'];

// http://stackoverflow.com/questions/15302618/node-js-check-if-module-is-installed-without-actually-requiring-it
child = exec("npm list --global", function (error, stdout, stderr) {
  deps.forEach(function(dep){
    if(stdout.indexOf(dep) == -1){
      console.log(dep + ' not found. Please run `npm install -g ' + dep + '`');
      deps_available = false;
    }
  });
});

return deps_available;