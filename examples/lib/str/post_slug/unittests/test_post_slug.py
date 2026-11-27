#!/usr/bin/env python3
"""
Unit tests for post_slug implementations
Tests new features: 255 char limit, HTML entities, error handling
"""

import unittest
import subprocess
import os
import sys

# Add parent directory to path
sys.path.insert(0, os.path.join(os.path.dirname(__file__), '..'))
from post_slug import post_slug


class TestPostSlug(unittest.TestCase):
    """Test cases for post_slug function"""
    
    def setUp(self):
        """Set up test fixtures"""
        self.test_dir = os.path.dirname(os.path.abspath(__file__))
        self.implementations = {
            'py': os.path.join(self.test_dir, '_post_slug.py'),
            'js': os.path.join(self.test_dir, '_post_slug.js'),
            'bash': os.path.join(self.test_dir, '_post_slug.sh'),
            'php': os.path.join(self.test_dir, '_post_slug.php')
        }
        # The C port takes part once built (cd c && make build)
        c_bin = os.path.join(self.test_dir, '..', 'c', '_post_slug')
        if os.access(c_bin, os.X_OK):
            self.implementations['c'] = c_bin

    def run_implementation(self, impl, *args, env=None):
        """Run a specific implementation and return output"""
        cmd = [self.implementations[impl]] + [a if isinstance(a, bytes) else str(a) for a in args]
        try:
            result = subprocess.run(cmd, capture_output=True, text=True, timeout=5, env=env)
            return result.stdout.strip()
        except subprocess.TimeoutExpired:
            return "TIMEOUT"
        except Exception as e:
            return f"ERROR: {e}"
    
    def check_all_implementations(self, input_str, sep_char='-', preserve_case=0, max_len=0):
        """Test all implementations return the same result"""
        results = {}
        for impl in self.implementations:
            results[impl] = self.run_implementation(impl, input_str, sep_char, preserve_case, max_len)
        
        # Check all results are the same
        unique_results = set(results.values())
        if len(unique_results) > 1:
            self.fail(f"Implementations differ for '{input_str}': {results}")
        
        return list(unique_results)[0]
    
    # Test 255 character limit
    def test_255_char_limit_exact(self):
        """Test string exactly 255 characters"""
        input_str = "1" * 257  # 257 chars
        result = self.check_all_implementations(input_str)
        self.assertEqual(len(result), 255, "Should truncate to 255 characters")
        self.assertEqual(result, "1" * 255)
    
    def test_255_char_limit_under(self):
        """Test string under 255 characters"""
        input_str = "test-string-under-limit"
        result = self.check_all_implementations(input_str)
        self.assertEqual(result, "test-string-under-limit")
    
    def test_255_char_limit_with_special_chars(self):
        """Test 255 limit with special characters"""
        input_str = "Test! String@ With# Special$ Chars% " * 20  # Long string
        result = self.check_all_implementations(input_str)
        self.assertLessEqual(len(result), 255)
        self.assertTrue(result.startswith("test-string-with-special-chars"))
    
    # Test HTML entity handling
    def test_html_entity_single(self):
        """Test single HTML entity"""
        result = self.check_all_implementations("Barnes &amp; Noble")
        self.assertEqual(result, "barnes-noble")
    
    def test_html_entity_multiple(self):
        """Test multiple HTML entities"""
        result = self.check_all_implementations("&lt;Test&gt; &amp; &quot;Example&quot;")
        self.assertEqual(result, "test-example")

    def test_html_entity_ends_at_first_semicolon(self):
        """An entity runs to the first ';', not the last one before a space"""
        result = self.check_all_implementations("AT&amp;T; Q&A")
        self.assertEqual(result, "at-t-q-a")
    
    def test_html_entity_with_custom_separator(self):
        """Test HTML entities with custom separator"""
        result = self.check_all_implementations("A &amp; B", "_")
        self.assertEqual(result, "a_b")
    
    # Test error handling
    def test_empty_string(self):
        """Test empty string input"""
        result = self.check_all_implementations("")
        self.assertEqual(result, "")
    
    def test_only_spaces(self):
        """Test string with only spaces"""
        result = self.check_all_implementations("   ")
        self.assertEqual(result, "")
    
    def test_only_special_chars(self):
        """Test string with only special characters"""
        result = self.check_all_implementations("!@#$%^&*()")
        self.assertEqual(result, "")
    
    def test_non_latin_script(self):
        """Test non-Latin script (should return empty)"""
        result = self.check_all_implementations("Привет мир")
        self.assertEqual(result, "")
    
    # Test case preservation
    def test_case_preservation_off(self):
        """Test default lowercase conversion"""
        result = self.check_all_implementations("iPhone iPad", "-", 0)
        self.assertEqual(result, "iphone-ipad")
    
    def test_case_preservation_on(self):
        """Test case preservation"""
        result = self.check_all_implementations("iPhone iPad", "-", 1)
        self.assertEqual(result, "iPhone-iPad")
    
    # Test custom separators
    def test_separator_underscore(self):
        """Test underscore separator"""
        result = self.check_all_implementations("Test Case", "_")
        self.assertEqual(result, "test_case")
    
    def test_separator_plus(self):
        """Test plus separator"""
        result = self.check_all_implementations("Test Case", "+")
        self.assertEqual(result, "test+case")
    
    def test_separator_period(self):
        """Test period separator"""
        result = self.check_all_implementations("Test Case", ".")
        self.assertEqual(result, "test.case")
    
    # Test real-world cases
    def test_real_world_covid(self):
        """Test COVID-19 title"""
        result = self.check_all_implementations("COVID-19: A Global Pandemic")
        self.assertEqual(result, "covid-19-a-global-pandemic")
    
    def test_real_world_currency(self):
        """Test currency symbols"""
        result = self.check_all_implementations("Price: $100.50 or €85.99")
        self.assertEqual(result, "price-100-50-or-eur85-99")
    
    def test_real_world_email(self):
        """Test email address"""
        result = self.check_all_implementations("Contact: user@example.com")
        self.assertEqual(result, "contact-user-example-com")
    
    def test_real_world_url(self):
        """Test URL"""
        result = self.check_all_implementations("Visit https://example.com/page")
        self.assertEqual(result, "visit-https-example-com-page")
    
    # Test edge cases
    def test_consecutive_separators(self):
        """Test multiple consecutive separators are collapsed"""
        result = self.check_all_implementations("Test   Multiple   Spaces")
        self.assertEqual(result, "test-multiple-spaces")
    
    def test_leading_trailing_special(self):
        """Test leading/trailing special characters"""
        result = self.check_all_implementations("!!!Test!!!")
        self.assertEqual(result, "test")
    
    def test_mixed_quotes(self):
        """Test various quote types"""
        result = self.check_all_implementations('“Smart quotes” and ‘curly apostrophes’')
        self.assertEqual(result, "smart-quotes-and-curly-apostrophes")

    # Characters with no ASCII form are deleted in every implementation
    def test_untranslatable_deleted(self):
        """Symbols with no ASCII form are deleted, not turned into separators"""
        result = self.check_all_implementations("x♠y §5 ¤ x♫y")
        self.assertEqual(result, "xy-5-xy")

    def test_iconv_only_forms_deleted(self):
        """¡, ♥ and soft hyphen are deleted although iconv has ASCII forms"""
        result = self.check_all_implementations("¡Hola! I♥NY co­operate")
        self.assertEqual(result, "hola-iny-cooperate")

    def test_pound_sign(self):
        """£ is spelt out, like €"""
        result = self.check_all_implementations("£98mn aid")
        self.assertEqual(result, "gbp98mn-aid")

    # The 255 limit counts characters, not bytes (PHP) or UTF-16 units (JS)
    def test_255_char_limit_multibyte(self):
        """255 two-byte characters survive the limit intact"""
        result = self.check_all_implementations("é" * 300)
        self.assertEqual(result, "e" * 255)

    def test_255_char_limit_astral(self):
        """Emoji count as one character each"""
        result = self.check_all_implementations("a😀" * 200)
        self.assertEqual(result, "a" * 128)

    def test_locale_independent(self):
        """Output does not change under LC_ALL=C (as under cron)"""
        env = dict(os.environ, LC_ALL='C', LANG='C')
        for impl in self.implementations:
            with self.subTest(impl=impl):
                self.assertEqual(self.run_implementation(impl, "Café Müller", env=env),
                                 "cafe-muller")

    def test_invalid_utf8_byte_level(self):
        """Invalid UTF-8 gives '' in the byte-level implementations"""
        for impl in ('php', 'bash', 'c'):
            if impl in self.implementations:
                with self.subTest(impl=impl):
                    self.assertEqual(self.run_implementation(impl, b'ab\xffcd'), '')


class TestPostSlugPHP(unittest.TestCase):
    """PHP-specific behaviour"""

    def test_host_locale_c(self):
        """A host program's setlocale(LC_CTYPE, 'C') does not break iconv"""
        root = os.path.join(os.path.dirname(os.path.abspath(__file__)), '..')
        code = ('require $argv[1] . "/post_slug.php"; setlocale(LC_CTYPE, "C");'
                ' echo post_slug("Café Müller"), "|", setlocale(LC_CTYPE, 0);')
        result = subprocess.run(['php', '-r', code, root], capture_output=True,
                                text=True, timeout=5)
        self.assertEqual(result.stdout, "cafe-muller|C")


class TestPostSlugPython(unittest.TestCase):
    """Test Python implementation directly"""
    
    def test_python_direct_import(self):
        """Test direct Python import works"""
        result = post_slug("Test String")
        self.assertEqual(result, "test-string")
    
    def test_python_error_handling(self):
        """Test Python error handling"""
        # This should not raise an exception
        result = post_slug(None)
        self.assertEqual(result, "")


if __name__ == '__main__':
    # Run with verbose output
    unittest.main(verbosity=2)