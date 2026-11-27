/* post_slug.c - URL/filename-friendly ASCII slug generator (C port).
 *
 * Byte-compatible with post_slug.{bash,php,py,js}.
 * Uses the PHP/Bash transliteration path: iconv UTF-8 -> ASCII//TRANSLIT.
 *
 * Build CLI:   cc -O2 -std=c11 -Wall -Wextra -o _post_slug post_slug.c
 * Build lib:   cc -O2 -std=c11 -DPOST_SLUG_LIB_ONLY -c post_slug.c
 *
 * Version: 1.1.0
 */
#define _GNU_SOURCE
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <ctype.h>
#include <errno.h>
#include <locale.h>
#include <iconv.h>
#include <regex.h>
#include <pthread.h>

#include "post_slug.h"

#define POST_SLUG_VERSION "1.1.0"

/* -------------------------------------------------------------------------- */
/* helpers                                                                    */
/* -------------------------------------------------------------------------- */

static char *xstrdup(const char *s) {
  size_t n = strlen(s) + 1;
  char *r = malloc(n);
  if (r) memcpy(r, s, n);
  return r;
}

static char *xempty(void) { return xstrdup(""); }

/* Replace every occurrence of needle in `in` with repl.
 * Frees `in` and returns a fresh malloc'd buffer. */
static char *str_replace_all(char *in, const char *needle, const char *repl) {
  if (!in) return NULL;
  size_t nlen = strlen(needle);
  if (nlen == 0) return in;
  size_t rlen = strlen(repl);
  size_t ilen = strlen(in);

  size_t count = 0;
  for (const char *p = in; (p = strstr(p, needle)); p += nlen) count++;
  if (count == 0) return in;

  size_t outlen = ilen
                + count * (rlen > nlen ? rlen - nlen : 0)
                - count * (rlen < nlen ? nlen - rlen : 0);
  char *out = malloc(outlen + 1);
  if (!out) { free(in); return NULL; }

  char *dst = out;
  const char *src = in;
  const char *match;
  while ((match = strstr(src, needle))) {
    size_t pre = (size_t)(match - src);
    memcpy(dst, src, pre); dst += pre;
    memcpy(dst, repl, rlen); dst += rlen;
    src = match + nlen;
  }
  strcpy(dst, src);
  free(in);
  return out;
}

/* Count UTF-8 codepoints (bytes whose top two bits are not 10). */
static size_t utf8_char_count(const char *s) {
  size_t n = 0;
  for (; *s; s++) if (((unsigned char)*s & 0xC0) != 0x80) n++;
  return n;
}

/* Copy at most max_chars UTF-8 codepoints from `in` into a fresh buffer. */
static char *utf8_truncate(const char *in, size_t max_chars) {
  size_t chars = 0;
  const char *p = in;
  while (*p) {
    if (((unsigned char)*p & 0xC0) != 0x80) {
      if (chars >= max_chars) break;
      chars++;
    }
    p++;
  }
  size_t bytes = (size_t)(p - in);
  char *out = malloc(bytes + 1);
  if (!out) return NULL;
  memcpy(out, in, bytes);
  out[bytes] = '\0';
  return out;
}

/* glibc iconv UTF-8 -> ASCII//TRANSLIT.
 * Returns malloc'd NUL-terminated string, or NULL on iconv_open failure. */
/* Delete emoji and pictographs, U+1F300..U+1FAFF (UTF-8 F0 9F 8C 80 ..
 * F0 9F AB BF), in place. They have no ASCII form, but iconv renders some
 * as ':-D' or '<3', while NFKD (the Python and JS modules) gives nothing.
 * Each test stops at the terminating NUL, so no byte past it is read; an
 * incomplete sequence is left for iconv to reject. */
static void drop_pictographs(char *s) {
  char *w = s;
  const char *r = s;
  while (*r) {
    const unsigned char *u = (const unsigned char *)r;
    if (u[0] == 0xF0 && u[1] == 0x9F && u[2] >= 0x8C && u[2] <= 0xAB
        && (u[3] & 0xC0) == 0x80) {
      r += 4;
      continue;
    }
    *w++ = *r++;
  }
  *w = '\0';
}

static char *iconv_translit(const char *in) {
  iconv_t cd = iconv_open("ASCII//TRANSLIT", "UTF-8");
  if (cd == (iconv_t)-1) return NULL;

  size_t inlen = strlen(in);
  size_t outcap = inlen * 4 + 16;
  char *out = malloc(outcap + 1);
  if (!out) { iconv_close(cd); return NULL; }

  char *inbuf = (char *)in;
  size_t inrem = inlen;
  char *outbuf = out;
  size_t outrem = outcap;

  while (inrem > 0) {
    size_t r = iconv(cd, &inbuf, &inrem, &outbuf, &outrem);
    if (r == (size_t)-1) {
      if (errno == E2BIG) {
        size_t used = (size_t)(outbuf - out);
        outcap *= 2;
        char *nb = realloc(out, outcap + 1);
        if (!nb) { free(out); iconv_close(cd); return NULL; }
        out    = nb;
        outbuf = out + used;
        outrem = outcap - used;
        continue;
      } else if (errno == EILSEQ || errno == EINVAL) {
        /* Invalid UTF-8. The bash and PHP modules' iconv call fails here and
         * they return ''; give an empty result too, so the slug is "". */
        outbuf = out;
        break;
      } else {
        break;
      }
    }
  }
  *outbuf = '\0';
  iconv_close(cd);
  return out;
}

/* -------------------------------------------------------------------------- */
/* post_slug                                                                  */
/* -------------------------------------------------------------------------- */

/* The slug pipeline. Runs under the locale pinned by post_slug(). */
static char *slugify(const char *input_str,
                     char sep_char,
                     int preserve_case,
                     size_t max_len) {
  /* (2) truncate input to 255 UTF-8 codepoints */
  char *s;
  if (utf8_char_count(input_str) > 255) {
    s = utf8_truncate(input_str, 255);
  } else {
    s = xstrdup(input_str);
  }
  if (!s) return NULL;

  /* (3-4) kludges — union of bash + php tables, applied in bash order.
   * Characters meant to become separators map to a plain '-' or ' ', which
   * step (10) converts to sep_char. Inserting sep_char itself here would let
   * step (7) delete it when sep_char is '?'. */
  #define K(NEEDLE, REPL) do { s = str_replace_all(s, (NEEDLE), (REPL)); \
                               if (!s) return NULL; } while (0)
  K("\xe2\x80\x94", "-");                      /* — em dash (bash)  */
  K("\xe2\x80\x93", "-");                      /* – en dash (php)   */
  K("\xc3\xa2\xef\xbf\xbd\xc2\xb9", "Rs");     /* mangled rupee (bash/php) */
  K("\xef\xbf\xbd", "-");                      /* U+FFFD replacement      */
  K("\xc2\xbd", "-");                          /* ½                  */
  K("\xc2\xbc", "-");                          /* ¼                  */
  K(" & ", " and ");
  K("\xe2\x98\x85", " ");                      /* ★                  */
  K("?", "-");                  /* keep real '?' apart from iconv's '?' (7) */
  K("\xe2\x82\xac", "EUR");                    /* €                  */
  K("\xc2\xa3", "GBP");                        /* £                  */
  K("\xc2\xa9", "C");                          /* ©                  */
  K("\xc2\xae", "R");                          /* ®                  */
  K("\xe2\x84\xa2", "-TM");                    /* ™                  */
  K("\xca\xbe", "");                           /* ʾ (php)            */
  /* iconv gives these an ASCII form that Python and JS do not ('!', ':-)',
   * '<3', '-'); delete them, as the other modules do. */
  K("\xc2\xa1", "");                           /* ¡                  */
  K("\xe2\x98\xba", "");                       /* ☺                  */
  K("\xe2\x98\xbb", "");                       /* ☻                  */
  K("\xe2\x99\xa1", "");                       /* ♡                  */
  K("\xe2\x99\xa5", "");                       /* ♥                  */
  K("\xe2\x9d\xa4", "");                       /* ❤                  */
  K("\xc2\xad", "");                           /* soft hyphen        */
  #undef K
  drop_pictographs(s);

  /* (5) HTML entities -> '-'. Only if both '&' and ';' present. An entity
   * runs from '&' to the first ';' before a space or tab, as in the other
   * modules' '&[^ \t;]*;'. */
  if (strchr(s, '&') && strchr(s, ';')) {
    regex_t re;
    if (regcomp(&re, "&[^ \t;]*;", REG_EXTENDED) == 0) {
      regmatch_t m;
      while (regexec(&re, s, 1, &m, 0) == 0) {
        size_t pre  = (size_t)m.rm_so;
        size_t tail = strlen(s + m.rm_eo);
        size_t newlen = pre + 1 + tail;
        char *ns = malloc(newlen + 1);
        if (!ns) { regfree(&re); free(s); return NULL; }
        memcpy(ns, s, pre);
        ns[pre] = '-';
        memcpy(ns + pre + 1, s + m.rm_eo, tail);
        ns[newlen] = '\0';
        free(s);
        s = ns;
      }
      regfree(&re);
    }
  }

  /* (6) transliterate to ASCII */
  {
    char *t = iconv_translit(s);
    if (!t) { free(s); return xempty(); }
    free(s);
    s = t;
  }

  /* (7) strip every '?' (TRANSLIT renders unmappable codepoints as '?') */
  {
    char *dst = s, *src = s;
    while (*src) { if (*src != '?') *dst++ = *src; src++; }
    *dst = '\0';
  }

  /* (8) strip quotes / apostrophes / backticks (bytes) */
  {
    char *dst = s, *src = s;
    while (*src) {
      unsigned char c = (unsigned char)*src;
      if (c == '`' || c == '\'' || c == '"' || c == 0xB4) { src++; continue; }
      *dst++ = (char)c;
      src++;
    }
    *dst = '\0';
  }

  /* (9) lowercase unless preserve_case */
  if (!preserve_case) {
    for (char *p = s; *p; p++) *p = (char)tolower((unsigned char)*p);
  }

  /* (10) replace any non-[A-Za-z0-9] byte with sep_char */
  for (char *p = s; *p; p++) {
    unsigned char c = (unsigned char)*p;
    if (!((c >= 'a' && c <= 'z') ||
          (c >= 'A' && c <= 'Z') ||
          (c >= '0' && c <= '9'))) {
      *p = sep_char;
    }
  }

  /* (11) collapse consecutive sep_char runs, strip leading/trailing */
  {
    char *dst = s, *src = s;
    while (*src == sep_char) src++;
    int prev_sep = 0;
    while (*src) {
      if (*src == sep_char) {
        if (!prev_sep) { *dst++ = sep_char; prev_sep = 1; }
      } else {
        *dst++ = *src; prev_sep = 0;
      }
      src++;
    }
    if (dst > s && *(dst - 1) == sep_char) dst--;
    *dst = '\0';
  }

  /* (12) truncate at max_len, then cut at last sep */
  if (max_len > 0) {
    size_t n = strlen(s);
    if (n > max_len) {
      s[max_len] = '\0';
      char *last = strrchr(s, sep_char);
      if (last) *last = '\0';
    }
  }

  return s;
}

/* iconv //TRANSLIT, regex classes and tolower() follow the thread's
 * LC_CTYPE; under LC_ALL=C, or a locale that is not installed, "café"
 * becomes "caf". Each call therefore runs under C.UTF-8 via uselocale(),
 * which is per-thread, so the host program's global locale is untouched.
 * The locale is built once: newlocale() costs ~40us, about 50 times the
 * rest of a typical call. It is never freed; one object per process. */
static locale_t       utf8_locale = (locale_t)0;
static pthread_once_t utf8_locale_once = PTHREAD_ONCE_INIT;

static void utf8_locale_init(void) {
  utf8_locale = newlocale(LC_ALL_MASK, "C.UTF-8", (locale_t)0);
}

char *post_slug(const char *input_str,
                char sep_char,
                int preserve_case,
                size_t max_len) {
  if (!input_str)        return xempty();
  if (sep_char == '\0')  sep_char = '-';
  /* A non-ASCII byte would put invalid UTF-8 into the slug. */
  if ((unsigned char)sep_char >= 0x80) return xempty();
  if (*input_str == '\0') return xempty();

  /* If C.UTF-8 is unavailable, fall back to the current locale. */
  pthread_once(&utf8_locale_once, utf8_locale_init);
  locale_t prev = utf8_locale ? uselocale(utf8_locale) : (locale_t)0;
  char *slug = slugify(input_str, sep_char, preserve_case, max_len);
  if (utf8_locale) uselocale(prev);
  return slug;
}

/* -------------------------------------------------------------------------- */
/* CLI (compiled in unless POST_SLUG_LIB_ONLY is defined)                     */
/* -------------------------------------------------------------------------- */
#ifndef POST_SLUG_LIB_ONLY

static const char usage_text[] =
  "post_slug " POST_SLUG_VERSION
  " - Convert strings into URL/filename-friendly ASCII slugs\n"
  "\n"
  "Usage: post_slug [--] <input_str> [sep_char] [preserve_case] [max_len]\n"
  "       post_slug --stdin [sep_char] [preserve_case] [max_len] < FILE\n"
  "\n"
  "Arguments:\n"
  "  input_str      String to convert (max 255 chars)\n"
  "  sep_char       Separator; one ASCII character (default: '-')\n"
  "  preserve_case  0=lowercase, 1=preserve (default: 0)\n"
  "  max_len        Max output length, 0=unlimited (default: 0)\n"
  "\n"
  "Options (first argument only):\n"
  "  --stdin        Read input strings from stdin, one per line; write one\n"
  "                 slug per line, empty lines included\n"
  "  -h, --help     Show this help\n"
  "  --             Treat the next argument as input_str, even '-h'\n"
  "\n"
  "Examples:\n"
  "  post_slug 'Hello, World!'           # hello-world\n"
  "  post_slug 'Hello, World!' _ 1       # Hello_World\n"
  "  post_slug 'Long title here' - 0 8   # long\n"
  "  post_slug --stdin _ < titles.txt    # one slug per line\n";

/* Parse a non-negative decimal. Empty means 0, as in the bash CLI.
 * Rejects signs, spaces, trailing junk and overflow: atoi() would turn a
 * typo such as "1O" into 1 without a word. */
static int parse_uint(const char *s, unsigned long long *out) {
  if (*s == '\0') { *out = 0; return 1; }
  for (const char *p = s; *p; p++) {
    if (*p < '0' || *p > '9') return 0;
  }
  errno = 0;
  *out = strtoull(s, NULL, 10);
  return errno == 0;
}

/* Write one slug and a newline. Returns 0 on allocation failure. */
static int emit(const char *input, char sep, int prsv, size_t mlen) {
  char *slug = post_slug(input, sep, prsv, mlen);
  if (!slug) {
    fputs("post_slug: out of memory\n", stderr);
    return 0;
  }
  fputs(slug, stdout);
  putchar('\n');
  free(slug);
  return 1;
}

int main(int argc, char **argv) {
  int argi = 1;
  int from_stdin = 0;
  if (argi < argc) {
    if (!strcmp(argv[argi], "-h") || !strcmp(argv[argi], "--help")) {
      fputs(usage_text, stdout);
      return 0;
    }
    if (!strcmp(argv[argi], "--stdin")) {
      from_stdin = 1;
      argi++;
    } else if (!strcmp(argv[argi], "--")) {
      argi++;
    }
  }
  if (!from_stdin && argi >= argc) {
    fputs(usage_text, stderr);
    return 2;
  }

  /* A literal "-" stays an input string: it is a valid title (slug ""),
   * and the validation harness passes dataset lines such as "-" here. */
  const char *input   = from_stdin ? NULL : argv[argi++];
  const char *sep_arg = (argi     < argc) ? argv[argi]     : "";
  const char *pc_arg  = (argi + 1 < argc) ? argv[argi + 1] : "";
  const char *ml_arg  = (argi + 2 < argc) ? argv[argi + 2] : "";

  char sep = sep_arg[0] ? sep_arg[0] : '-';
  if ((unsigned char)sep >= 0x80) {
    fputs("post_slug: sep_char must be a single ASCII character\n", stderr);
    return 22;
  }
  unsigned long long prsv, mlen;
  if (!parse_uint(pc_arg, &prsv) || !parse_uint(ml_arg, &mlen)) {
    fputs("post_slug: preserve_case and max_len must be non-negative integers\n",
          stderr);
    return 22;
  }

  if (!from_stdin) {
    if (!emit(input, sep, prsv != 0, (size_t)mlen)) return 1;
  } else {
    /* Stdin mode: one process for any number of lines. Output stays
     * line-aligned with input, so `paste` can pair them. */
    char *line = NULL;
    size_t cap = 0;
    ssize_t len;
    while ((len = getline(&line, &cap, stdin)) != -1) {
      if (len > 0 && line[len - 1] == '\n') line[len - 1] = '\0';
      if (!emit(line, sep, prsv != 0, (size_t)mlen)) {
        free(line);
        return 1;
      }
    }
    free(line);
    if (ferror(stdin)) {
      perror("post_slug: stdin");
      return 1;
    }
  }

  if (fflush(stdout) == EOF || ferror(stdout)) {
    perror("post_slug: stdout");
    return 1;
  }
  return 0;
}
#endif

/* fin */
