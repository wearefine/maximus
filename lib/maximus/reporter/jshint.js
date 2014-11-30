/* jshint node: true */

"use strict";

module.exports = {
  reporter: function (res) {
    var str = {};
    var files = {};
    res.forEach(function (r) {
      var err = r.error;
      var reform = {};
      if (!files[r.file]) {
        files[r.file] = [];
      }
      reform.linter = err.code;
      reform.severity = err.code.indexOf('W') > - 1 ? 'warning' : 'error';
      reform.reason = err.reason;
      reform.line = err.line;
      reform.column = err.character;
      files[r.file].push(reform);
    });

    if (res.length) {
      str = files;
      process.stdout.write(JSON.stringify(str));
    }
  }
};
