#!/usr/bin/env python3
"""_post_slug.py - command-line driver for post_slug.py, used by the tests.

Usage: _post_slug.py input_str [sep_char [preserve_case [max_len]]]
       _post_slug.py --stdin [sep_char [preserve_case [max_len]]]

--stdin prints one slug per input line, empty lines included.
"""
import os
import sys

sys.path.insert(0, os.path.join(os.path.dirname(os.path.realpath(__file__)), '..'))
from post_slug import post_slug  # noqa: E402  (needs the path set above)


def main(argv: list[str]) -> int:
  from_stdin = bool(argv) and argv[0] == '--stdin'
  args = argv[1:] if from_stdin else argv
  if not from_stdin and not args:
    print(__doc__.strip(), file=sys.stderr)
    return 2
  opts = args if from_stdin else args[1:]
  sep_char = opts[0] if len(opts) > 0 else '-'
  preserve_case = int(opts[1]) if len(opts) > 1 else 0
  max_len = int(opts[2]) if len(opts) > 2 else 0

  if not from_stdin:
    print(post_slug(args[0], sep_char, preserve_case, max_len))
    return 0
  with open(0, encoding='utf-8', errors='surrogateescape', newline='\n') as fh:
    for line in fh:
      print(post_slug(line.removesuffix('\n'), sep_char, preserve_case, max_len))
  return 0


if __name__ == '__main__':
  sys.exit(main(sys.argv[1:]))
