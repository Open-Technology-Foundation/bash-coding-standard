//#!/usr/bin/env node
/**
 * Function: post_slug(inputStr: string, sepChar: string = "-", preserveCase: boolean = false, maxLen: number = 0) -> string
 * 
 * The `post_slug` function provides a utility for converting a given string into a URL or filename-friendly slug.
 * 
 * - Limits input to 255 characters to ensure filesystem compatibility.
 * - Replaces all HTML entities with `sepChar`.
 * - Forces all characters in `inputStr` to ASCII (or closest representation).
 * - Removes quotes, apostrophes, and backticks.
 * - Forces to lowercase if not `preserveCase`.
 * - Replaces all non-alphanumeric characters with `sepChar`.
 * - Removes all repetitions of `sepChar`.
 * - Strips `sepChar` from ends of string.
 * - Returns empty string on any error for safe failure handling.
 * 
 * @param {string} inputStr - The string to be converted into a slug. Automatically truncated to 255 characters.
 * @param {string} sepChar - The character to replace non-alphanumeric characters (default: '-').
 * @param {boolean} preserveCase - Whether to retain the original case of the string (default: false).
 * @param {number} maxLen - The maximum length for the slug (default: 0 = no limit beyond 255 char input limit).
 * @returns {string} - The resulting slug, or empty string on error.
 * 
 * @version 1.1.0
 * @changelog
 * 1.1.0 - 255 limit counts code points, not UTF-16 units; HTML entity
 *         match ends at the first ';'; '£' becomes 'GBP'; exported via
 *         module.exports for Node.
 * 1.0.1 - Added 255 character input limit, fixed HTML entity handling, 
 *         improved regex escaping, added try-catch error handling.
 * 1.0.0 - Initial release
 */

/**
 * Transliteration Kludges
 * Create translation table for single-character replacements.
 */
const translationTable = {
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
  'ʼ': '',
  '´': '',
  'ʾ': ''
};

/**
 * Kludge Dictionary for multi-character replacements.
 */
const multiCharReplacements = {
  ' & ': ' and ',
  'œ': 'oe',
  '™': '-TM',
  'Œ': 'OE',
  'ß': 'ss',
  'æ': 'ae',
  'â�¹': 'Rs',
  '�': '-',
  '€': 'EUR',  // Euro symbol - match iconv transliteration
  '£': 'GBP',  // Pound sign - match iconv transliteration
  '©': 'C',    // Copyright symbol
  '®': 'R',    // Registered trademark
};

function post_slug(inputStr, sepChar = "-", preserveCase = false, maxLen = 0) {
  try {
    // Handle empty replacement character
    if (sepChar == '') sepChar = '-';
    sepChar = sepChar[0]
    
    // Limit input to 255 characters (code points, as in the other modules;
    // .length counts UTF-16 units and would split a surrogate pair)
    const codePoints = Array.from(inputStr);
    if (codePoints.length > 255) {
      inputStr = codePoints.slice(0, 255).join('');
    }
    
    // Kludges to increase cross platform slug similiarity.
    /**
     * Apply single-character replacements
     */
  for (const [oldChar, newChar] of Object.entries(translationTable)) {
    const regex = new RegExp(oldChar, 'g');
    inputStr = inputStr.replace(regex, newChar);
  }
    /**
     * Apply multi-character replacements.
     */
  for (const [oldStr, newStr] of Object.entries(multiCharReplacements)) {
    const regex = new RegExp(oldStr, 'g');
    inputStr = inputStr.replace(regex, newStr);
  }

  // Remove all HTML entities; an entity ends at the first ';'.
  inputStr = inputStr.replace(/&[^ \t;]*;/g, sepChar);

  // Force all characters in `input_str` to ASCII (or closest representation).
  // Characters with no ASCII form are deleted, as in the other modules.
  inputStr = inputStr.normalize("NFKD").replace(/[^\x00-\x7F]/g, "");

  // Remove quotes, apostrophes, and backticks.
  inputStr = inputStr.replace(/[`'"’´]/g, "");
  
  // Optionally convert to lowercase
  if (!preserveCase) inputStr = inputStr.toLowerCase();
  
  // Replace all non-alphanumeric characters with sepChar
  inputStr = inputStr.replace(/[^a-zA-Z0-9]/g, sepChar);
  
  // Escape special characters in sepChar
  const escapedSepChar = sepChar.replace(/[\\^$.*+?()[\]{}|]/g, "\\$&");
  
  /* Return only valid alpha-numeric chars and the `sep_char` char, 
     replacing all other chars with the `sep_char` char, 
     then removing all repetitions of `sep_char` within the string, 
     and stripping `sep_char` from ends of the string. */
  const sepCharPattern = new RegExp(`${escapedSepChar}+`, "g");
  inputStr = inputStr.replace(sepCharPattern, sepChar);
  
  // Remove leading and trailing sepChar
  inputStr = inputStr.replace(new RegExp(`^${escapedSepChar}|${escapedSepChar}$`, "g"), "");
  
  // Implement the maxLen feature
  if (maxLen && inputStr.length > maxLen) {
    inputStr = inputStr.substring(0, maxLen);
    const lastSepCharPos = inputStr.lastIndexOf(sepChar);
    if (lastSepCharPos !== -1) {
      inputStr = inputStr.substring(0, lastSepCharPos);
    }
  }
    return inputStr;
  } catch (e) {
    return "";
  }
}

// CommonJS export, so `const { post_slug } = require('./post_slug.js')` works.
// The guard keeps the file usable as a plain <script> in a browser.
if (typeof module !== 'undefined' && module.exports) {
  module.exports = { post_slug };
}

//fin
