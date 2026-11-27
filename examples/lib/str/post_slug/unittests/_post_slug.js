#!/usr/bin/env node
// _post_slug.js - command-line driver for post_slug.js, used by the tests.
//
// Usage: _post_slug.js input_str [sep_char [preserve_case [max_len]]]
//        _post_slug.js --stdin [sep_char [preserve_case [max_len]]]
//
// --stdin prints one slug per input line, empty lines included.
'use strict';
const fs = require('fs');
const path = require('path');
const { post_slug } = require(path.join(__dirname, '..', 'post_slug.js'));

const argv = process.argv.slice(2);
const fromStdin = argv[0] === '--stdin';
const args = fromStdin ? argv.slice(1) : argv;
if (!fromStdin && args.length === 0) {
  process.stderr.write('Usage: _post_slug.js input_str [sep_char [preserve_case [max_len]]]\n' +
                       '       _post_slug.js --stdin [sep_char [preserve_case [max_len]]]\n');
  process.exit(2);
}
const opts = fromStdin ? args : args.slice(1);
const sepChar = opts[0] ?? '-';
const preserveCase = Number(opts[1] ?? 0) !== 0;
const maxLen = Number(opts[2] ?? 0);

if (!fromStdin) {
  console.log(post_slug(args[0], sepChar, preserveCase, maxLen));
} else {
  const lines = fs.readFileSync(0, 'utf8').split('\n');
  if (lines[lines.length - 1] === '') lines.pop();   // text ended with '\n'
  if (lines.length) {
    process.stdout.write(lines.map(l => post_slug(l, sepChar, preserveCase, maxLen)).join('\n') + '\n');
  }
}

//fin
