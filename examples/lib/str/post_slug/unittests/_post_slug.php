#!/usr/bin/env php
<?php
// _post_slug.php - command-line driver for post_slug.php, used by the tests.
//
// Usage: _post_slug.php input_str [sep_char [preserve_case [max_len]]]
//        _post_slug.php --stdin [sep_char [preserve_case [max_len]]]
//
// --stdin prints one slug per input line, empty lines included.
require_once __DIR__ . '/../post_slug.php';

$args = array_slice($argv, 1);
$from_stdin = ($args[0] ?? '') === '--stdin';
if ($from_stdin) {
  array_shift($args);
} elseif (!$args) {
  fwrite(STDERR, "Usage: _post_slug.php input_str [sep_char [preserve_case [max_len]]]\n"
               . "       _post_slug.php --stdin [sep_char [preserve_case [max_len]]]\n");
  exit(2);
}
$opts = $from_stdin ? $args : array_slice($args, 1);
$sep_char = $opts[0] ?? '-';
$preserve_case = (int)($opts[1] ?? 0);
$max_len = (int)($opts[2] ?? 0);

if (!$from_stdin) {
  echo post_slug($args[0], $sep_char, $preserve_case, $max_len), "\n";
  exit(0);
}
while (($line = fgets(STDIN)) !== false) {
  if (substr($line, -1) === "\n") $line = substr($line, 0, -1);
  echo post_slug($line, $sep_char, $preserve_case, $max_len), "\n";
}

// fin
