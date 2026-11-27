#!/usr/bin/env python3
"""spacetime - Format and display current time with optional template support.

Usage: spacetime([template])
  Without arguments: Returns formatted time as
    "DayOfWeek YYYY-MM-DD HH:MM:SS TZ Timezone"
  With template: Returns custom format using placeholders:
    {{dow}}      - Day of week (e.g., Monday)
    {{date}}     - Date in YYYY-MM-DD format
    {{time}}     - Time in HH:MM:SS format
    {{tz}}       - Timezone offset (e.g., +0000)
    {{timezone}} - Timezone name (e.g., America/New_York)
"""
from __future__ import annotations

import os
import sys
from datetime import datetime
from zoneinfo import ZoneInfo, ZoneInfoNotFoundError

__version__ = '1.2.0'
__all__ = ['spacetime', 'EPOCHSPACETIME', '__version__']

EPOCHSPACETIME: str = ''
_cached_timezone: str | None = None


def _resolve_system_timezone() -> str:
  """Resolve the system timezone name via a fallback chain.

  Mirrors the bash implementation:
    1. /etc/timezone (standard on Debian/Ubuntu)
    2. readlink /etc/localtime target (zoneinfo path)
    3. UTC
  """
  try:
    with open('/etc/timezone', encoding='utf-8') as f:
      name = f.read().strip()
      if name:
        return name
  except OSError:
    pass
  try:
    link = os.readlink('/etc/localtime')
    marker = 'zoneinfo/'
    idx = link.find(marker)
    if idx != -1:
      return link[idx + len(marker):]
  except OSError:
    pass
  return 'UTC'


def spacetime(template: str | None = None) -> str:
  """Format current time, optionally via a placeholder template.

  Honours TZ env var. Per POSIX, TZ='' (set but empty) means UTC.
  When TZ is unset, the system timezone is resolved once and cached.
  The result is also stored in the module-level EPOCHSPACETIME.
  """
  global EPOCHSPACETIME, _cached_timezone

  # Resolve timezone: honour TZ env var (set-but-empty → UTC per POSIX).
  if 'TZ' in os.environ:
    tz_name = os.environ['TZ'] or 'UTC'
  else:
    if _cached_timezone is None:
      _cached_timezone = _resolve_system_timezone()
    tz_name = _cached_timezone

  try:
    tz_obj = ZoneInfo(tz_name)
  except ZoneInfoNotFoundError:
    tz_name = 'UTC'
    tz_obj = ZoneInfo('UTC')

  now = datetime.now(tz_obj)
  dow = now.strftime('%A')
  cur_date = now.strftime('%Y-%m-%d')
  cur_time = now.strftime('%H:%M:%S')
  tz = now.strftime('%z')  # +0700 format (no colon)
  timezone = tz_name

  if template is None:
    result = f'{dow} {cur_date} {cur_time} {tz} {timezone}'
  else:
    result = (
      template
      .replace('{{dow}}', dow)
      .replace('{{date}}', cur_date)
      .replace('{{time}}', cur_time)
      .replace('{{tz}}', tz)
      .replace('{{timezone}}', timezone)
    )

  EPOCHSPACETIME = result
  return result


_HELP_TEMPLATE = '''\
__NAME__ __VERSION__ - Format and display current time with template support

Usage: __NAME__ [options] [--] [template]

Without arguments: Returns formatted time as
  "DayOfWeek YYYY-MM-DD HH:MM:SS TZ Timezone"

With template: Returns custom format using placeholders

Options:
  -V, --version  Show version and exit
  -h, --help     Show this help and exit
  --             End of options; required before a template beginning with '-'

Placeholders:
  {{dow}}      - Day of week (e.g., Monday)
  {{date}}     - Date in YYYY-MM-DD format
  {{time}}     - Time in HH:MM:SS format
  {{tz}}       - Timezone offset (e.g., +0000)
  {{timezone}} - Timezone name (e.g., America/New_York)

Examples:
  __NAME__
  TZ=UTC __NAME__
  __NAME__ "{{date}} at {{time}}"
  __NAME__ "Log entry: {{dow}} {{date}} {{time}} {{tz}}"
  __NAME__ -- "-- {{date}} --"'''


def _main(argv: list[str]) -> int:
  script_name = os.path.basename(argv[0]) if argv else 'spacetime.py'
  # Same rules as the Bash parse loop: options anywhere, '--' ends options,
  # any other dash-leading argument is an error (exit 22)
  positional: list[str] = []
  args = argv[1:]
  for i, arg in enumerate(args):
    if arg in ('-V', '--version'):
      print(f'{script_name} {__version__}')
      return 0
    if arg in ('-h', '--help'):
      print(_HELP_TEMPLATE.replace('__NAME__', script_name).replace('__VERSION__', __version__))
      return 0
    if arg == '--':
      positional.extend(args[i + 1:])
      break
    if arg.startswith('-'):
      quoted = "'" + arg.replace("'", "'\\''") + "'"
      print(f'{script_name}: invalid option {quoted} (use -- before a template beginning with -)',
            file=sys.stderr)
      return 22
    positional.append(arg)

  template = positional[0] if positional else None
  print(spacetime(template))
  return 0


if __name__ == '__main__':
  sys.exit(_main(sys.argv))

#fin
