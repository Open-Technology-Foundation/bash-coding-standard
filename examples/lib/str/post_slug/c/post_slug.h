/* post_slug.h - URL/filename-friendly ASCII slug generator (C port).
 *
 * Byte-compatible with the peer post_slug.{py,bash,php,js} implementations.
 * Follows the PHP/Bash transliteration path (iconv UTF-8 -> ASCII//TRANSLIT).
 *
 * Version: 1.1.0
 */
#ifndef POST_SLUG_H
#define POST_SLUG_H

#include <stddef.h>

#ifdef __cplusplus
extern "C" {
#endif

/* Convert input_str to a URL/filename-friendly ASCII slug.
 *
 * sep_char       Any ASCII byte; '\0' is treated as '-'. A non-ASCII byte
 *                (>= 0x80) is an error: the result is an empty string.
 * preserve_case  0 = lowercase, non-zero = preserve.
 * max_len        0 = unlimited; else truncate at last sep_char within max_len.
 *
 * Output does not depend on the caller's locale: each call runs under
 * C.UTF-8 via uselocale(), which is per-thread and restored on return.
 *
 * Returns a heap-allocated, NUL-terminated string the caller must free().
 * Returns NULL only on allocation failure; on any other error returns a
 * malloc'd empty string (matching the "empty string on failure" contract
 * of the peer modules).
 */
char *post_slug(const char *input_str,
                char        sep_char,
                int         preserve_case,
                size_t      max_len);

#ifdef __cplusplus
}
#endif

#endif /* POST_SLUG_H */
