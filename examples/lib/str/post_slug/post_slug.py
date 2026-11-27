#!/usr/bin/env python
"""
# post_slug Module

This module provides a utility function `post_slug` for converting a given string into a URL or filename-friendly slug.

The function performs multiple transformations to ensure the resulting slug is readable and safe for use in URLs or filenames. Specifically, it:

  - Limits input to 255 characters to ensure filesystem compatibility.
  - Replaces certain platform-specific characters with the separator character.
  - Replaces all HTML entities with the separator character.
  - Converts all characters to ASCII (or the closest representation).
  - Removes quotes, apostrophes, and backticks.
  - Converts the string to lowercase unless specified otherwise.
  - Retains only valid alphanumeric characters, replacing others with a separator character.
  - Optionally truncates the string to a maximum length, cutting off at the last separator character.
  - Returns empty string on any error for safe failure handling.

### Parameters:

    - `input_str` (str): The string to be converted into a slug. Automatically truncated to 255 characters.
    - `sep_char` (str, optional): The character used to replace non-alphanumeric characters. Default is '-'.
    - `preserve_case` (bool, optional): If True, retains the original case of the string. Default is False.
    - `max_len` (int, optional): Maximum length for the resulting string. Default is 0, which means no limit (beyond the 255 char input limit).

### Returns:

    - str: The resulting slug.

## Example Usage:

```python
from post_slug import post_slug

print(post_slug("Hello, World!"))
# Output: "hello-world"

print(post_slug("Hello, World!", '_', True))
# Output: "Hello_World"

print(post_slug("A title, with Ŝtřãņġę cHaracters ()"))
# Output: "a-title-with-strange-characters"

print(post_slug(" A title, with Ŝtřãņġę cHaracters ()", "_", True))
# Output: "A_title_with_strange_characters"
```

## Kludge transliterations

Manual Transliterations are required to account for the 
small number of inconsistencies in translation that might 
appear.

The Python and Javascript function modules use 
    unicodedata.normalize('NFKD', ...)

whereas Bash and PHP use:
    iconv('UTF-8', 'ASCII//TRANSLIT', ...)

Thus Python and Javascript in particular require their different
Kludge Tables.  Bash only requires a few kludgy fixups, while PHP
required very few.

This means, that these modules are not 100% accurate in situations
where Non-Latin text is used or embedded. However, depending on 
the input used, this is statistically insignificant using 
real world data.

## Requires:

    - Python 3.10 or higher
    - `re` and `unicodedata` modules

## Version:

    1.1.0

"""
__version__ = '1.1.0'
import re
import unicodedata

translation_table = str.maketrans({
  '–': '-',
  '½': '-',
  '¼': '-',
  'ı': 'i',
  '•': 'o',
  'ł': 'l',
  '—': '-',
  '★': ' ',
  'ø': 'o',
  'Đ': 'D',
  'ð': 'd',
  'đ': 'd',
  'Ł': 'L',
  '´': '',
})

multi_char_replacements = {
  ' & ': ' and ', # this is questionable; only valid for English.
  'œ': 'oe',
  '™': '-TM',
  'Œ': 'OE',
  'ß': 'ss',
  'æ': 'ae',
  'â�¹': 'Rs',
  '�': '-',
  '€': 'EUR',  # Euro symbol - match iconv transliteration
  '£': 'GBP',  # Pound sign - match iconv transliteration
  '©': 'C',    # Copyright symbol
  '®': 'R',    # Registered trademark
}

# Precompile regular expressions
ps_html_entity_re = re.compile(r'&[^ \t;]*;')  # an entity ends at the first ';'
ps_non_alnum_re = re.compile(r'[^a-zA-Z0-9]+')
ps_quotes_re = re.compile(r"[\"'`’´]")

def post_slug(input_str: str, sep_char: str = '-',
    preserve_case: bool = False, max_len: int = 0) -> str:
  """
  Convert a given string into a URL or filename-friendly slug.

  This function performs multiple transformations on the input string to create
  a slug that is both human-readable and safe for use in URLs or filenames.

  Parameters:
  ----------
  input_str : str
      The string to be converted into a slug.
  sep_char : str, optional
      The character used to replace any non-alphanumeric characters. Defaults to '-'.
  preserve_case : bool, optional
      If True, retains the original case of the string. Defaults to False.
  max_len : int, optional
      Maximum length for the resulting string. If set, the string may be truncated. Defaults to 0.

  Returns:
  -------
  str
      The resulting slug.

  Examples:
  --------
  >>> post_slug("Hello, World!")
  'hello-world'

  >>> post_slug("Hello, World!", "_", True)
  'Hello_World'

  >>> post_slug("A title, with Ŝtřãņġę cHaracters ()")
  'a-title-with-strange-characters'

  >>> post_slug(" A title, with Ŝtřãņġę cHaracters ()", "_", True)
  'A_title_with_strange_characters'

  Requires:
  --------
  Python 3.10 or higher.
  Modules `re` and `unicodedata`.

  Version:
  --------
  1.1.0
  
  Changelog:
  ----------
  1.1.0 - HTML entity match ends at the first ';'. '£' becomes 'GBP'.
  1.0.1 - Added 255 character input limit, standardized HTML entity handling,
          added error handling with try-except block.
  1.0.0 - Initial release
  """
  try:
    # Empty `sep_char` not permitted.
    if sep_char == '': sep_char = '-'
    sep_char = sep_char[0]
    
    # Limit input to 255 characters
    if len(input_str) > 255:
      input_str = input_str[:255]

    # Kludges to increase cross platform output similarity.
    # Apply single-character replacements using str.translate()
    input_str = input_str.translate(translation_table)

    # Apply multi-character replacements using a single regex substitution
    input_str = re.sub('|'.join(re.escape(key) for key in multi_char_replacements.keys()),
                       lambda m: multi_char_replacements[m.group(0)], input_str)

    # Remove all HTML entities.
    input_str = ps_html_entity_re.sub(sep_char, input_str)

    # Force all characters in `input_str` to ASCII (or closest representation).
    input_str = unicodedata.normalize('NFKD', input_str).encode('ASCII', 'ignore').decode()

    # Remove quotes, apostrophes, and backticks.
    input_str = ps_quotes_re.sub('', input_str)

    # Force to lowercase if not preserve_case.
    if not preserve_case:
      input_str = input_str.lower()

    # Return only valid alpha-numeric chars and the `sep_char` char,
    # replacing all other chars with the `sep_char` char,
    # then removing all repetitions of `sep_char` within the string,
    # and stripping `sep_char` from ends of the string.
    input_str = ps_non_alnum_re.sub(sep_char, input_str).strip(sep_char)

    # If max_len > 0, then check for overlength string,
    # and truncate on last sep_char.
    if max_len and len(input_str) > max_len:
      input_str = input_str[:max_len]
      last_sep_char_pos = input_str.rfind(sep_char)
      if last_sep_char_pos != -1:
        input_str = input_str[:last_sep_char_pos]

    return input_str
  except Exception:
    return ""

#fin
