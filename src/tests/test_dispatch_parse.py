"""Unit tests for dispatch.py parsing — the lenient one-file coder format."""
from __future__ import annotations

from clawforge import dispatch


class TestParseFile:
    def test_exact_delimiter_format(self):
        text = "PATH: docs/notes.md\n<<<FILE\n# Notes\nbody\nFILE>>>"
        path, content = dispatch._parse_file(text, "default.md")
        assert path == "docs/notes.md"
        assert content == "# Notes\nbody"

    def test_leading_slash_stripped(self):
        text = "PATH: /README.md\n<<<FILE\nhello\nFILE>>>"
        path, _ = dispatch._parse_file(text, "default.md")
        assert path == "README.md"

    def test_code_fence_fallback(self):
        text = "Here is the file:\n```markdown\n# Title\n```"
        path, content = dispatch._parse_file(text, "default.md")
        assert path == "default.md"
        assert content == "# Title\n"

    def test_fence_with_path_hint(self):
        text = "file: docs/guide.md\n```\ncontent\n```"
        path, content = dispatch._parse_file(text, "default.md")
        assert path == "docs/guide.md"
        assert content == "content\n"

    def test_raw_prose_last_resort(self):
        path, content = dispatch._parse_file("just prose", "default.md")
        assert path == "default.md"
        assert content == "just prose\n"


class TestDefaultPath:
    def test_readme_keyword(self):
        assert dispatch._default_path({"title": "Add a root README file"}) == "README.md"

    def test_contributing_keyword(self):
        assert dispatch._default_path({"title": "add CONTRIBUTING guide"}) == "CONTRIBUTING.md"

    def test_generic_title_slugged_into_docs(self):
        assert dispatch._default_path({"title": "Fix the Foo Bar!"}) == "docs/fix-the-foo-bar.md"

    def test_empty_title(self):
        assert dispatch._default_path({"title": ""}) == "docs/change.md"


class TestSlug:
    def test_slug_normalizes(self):
        assert dispatch._slug("Add a --version flag!") == "add-a-version-flag"

    def test_slug_caps_length(self):
        assert len(dispatch._slug("x" * 100)) <= 40
