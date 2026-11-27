import time

def elapsed_time(start_time, end_time=None):
  """
Format elapsed time as a human-readable string showing days, hours, minutes, seconds.

Args:
  start_time: Starting time from time.perf_counter()
  end_time: Ending time (defaults to current time)

Returns:
  String formatted as "[Nd] [NNh] [NNm] N.NNNs"
  """

  # Use current time if end_time not provided
  if end_time is None:
    end_time = time.perf_counter()
  
  elapsed = end_time - start_time

  # Round to whole milliseconds before splitting, so 59.9996s carries into the
  # minute instead of printing as "60.000s" (half away from zero, as in Bash)
  total_ms = int(elapsed * 1000 + (0.5 if elapsed >= 0 else -0.5))

  days, rem_ms = divmod(total_ms, 86_400_000)
  hours, rem_ms = divmod(rem_ms, 3_600_000)
  minutes, rem_ms = divmod(rem_ms, 60_000)

  parts = []
  if days:
    parts.append(f"{days}d")
  if hours or days:  # Show hours if we have days
    parts.append(f"{hours:02}h")
  if minutes or hours or days:  # Show minutes if we have hours/days
    parts.append(f"{minutes:02}m")

  # Integer formatting: no float error, and seconds are not zero-padded (Bash parity)
  parts.append(f"{rem_ms // 1000}.{rem_ms % 1000:03}s")
  
  return " ".join(parts)

#fin
