<?php
/**
 * spacetime - Format and display current time with optional template support
 *
 * Usage: spacetime([template])
 *   Without arguments: Returns formatted time as
 *     "DayOfWeek YYYY-MM-DD HH:MM:SS TZ Timezone"
 *   With template: Returns custom format using placeholders:
 *     {{dow}}      - Day of week (e.g., Monday)
 *     {{date}}     - Date in YYYY-MM-DD format
 *     {{time}}     - Time in HH:MM:SS format
 *     {{tz}}       - Timezone offset (e.g., +0000)
 *     {{timezone}} - Timezone name (e.g., America/New_York)
 *
 * @param string|null $template Optional template string with placeholders
 * @return string Formatted time string
 */
function spacetime(?string $template = null): string {
  // Resolve timezone name
  // If TZ env var is set (even empty), use it directly (POSIX: TZ='' means UTC).
  // If TZ is unset, use cached system timezone.
  static $cached_timezone = null;
  $tz_env = getenv('TZ');
  if ($tz_env !== false) {
    $timezone_name = ($tz_env === '') ? 'UTC' : $tz_env;
    try {
      $tz_obj = new DateTimeZone($timezone_name);
    } catch (\Exception $e) {
      $timezone_name = 'UTC';
      $tz_obj = new DateTimeZone('UTC');
    }
  } else {
    if ($cached_timezone === null) {
      $cached_timezone = date_default_timezone_get();
    }
    $timezone_name = $cached_timezone;
    $tz_obj = new DateTimeZone($timezone_name);
  }

  $now = new DateTime('now', $tz_obj);
  $dow = $now->format('l');
  $date = $now->format('Y-m-d');
  $time = $now->format('H:i:s');
  $tz = $now->format('O'); // +0000 format (no colon)
  $timezone = $timezone_name;

  // Default format when no template provided
  $curtime = "$dow $date $time $tz $timezone";

  // If a template string is provided, parse and replace placeholders
  if ($template !== null) {
    $curtime = str_replace(
      ['{{dow}}', '{{date}}', '{{time}}', '{{tz}}', '{{timezone}}'],
      [$dow, $date, $time, $tz, $timezone],
      $template
    );
  }

  // Store the result in the global variable for later reference
  $GLOBALS['EPOCHSPACETIME'] = $curtime;

  return $curtime;
}

// If script is executed directly, run spacetime with arguments
if (basename(__FILE__) === basename($_SERVER['SCRIPT_FILENAME'] ?? '')) {
  $VERSION = '1.2.0';
  $script_name = basename(__FILE__);

  // Same rules as the Bash parse loop: options anywhere, '--' ends options,
  // any other dash-leading argument is an error (exit 22)
  $positional = [];
  $args = array_slice($argv, 1);
  foreach ($args as $i => $arg) {
    if ($arg === '-V' || $arg === '--version') {
      echo "$script_name $VERSION\n";
      exit(0);
    }
    if ($arg === '-h' || $arg === '--help') {
      echo <<<'EOF'
spacetime - Format and display current time with template support

Usage: spacetime [options] [--] [template]

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
  spacetime.php
  TZ=UTC spacetime.php
  spacetime.php "{{date}} at {{time}}"
  spacetime.php "Log entry: {{dow}} {{date}} {{time}} {{tz}}"
  spacetime.php -- "-- {{date}} --"
EOF;
      echo "\n";
      exit(0);
    }
    if ($arg === '--') {
      array_push($positional, ...array_slice($args, $i + 1));
      break;
    }
    if (str_starts_with($arg, '-')) {
      $quoted = "'" . str_replace("'", "'\\''", $arg) . "'";
      fwrite(STDERR, "$script_name: invalid option $quoted (use -- before a template beginning with -)\n");
      exit(22);
    }
    $positional[] = $arg;
  }

  echo spacetime($positional[0] ?? null) . "\n";
}

#fin
