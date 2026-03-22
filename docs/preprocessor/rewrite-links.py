import json
import logging
import re
import sys
import tempfile
import unittest
from pathlib import Path
from urllib.parse import quote

MARKDOWN_LINK_RE = re.compile(r"\[([^\]]+)\]\(([^)\s]+)\)")
HTML_LINK_RE = re.compile(
    r'(<a\s+[^>]*href=")([^"]+)("[^>]*>)(.*?)(</a>)', re.IGNORECASE
)

REPO_ROOT_NAMES = {"modules", "flake", "lib", "hosts", "home", "pkgs", "overlays"}
LOGGER = logging.getLogger("rewrite-links")


def configure_logging() -> None:
    logging.basicConfig(
        level=logging.DEBUG,
        format="[rewrite-links] %(levelname)s: %(message)s",
        stream=sys.stderr,
    )


def is_external_link(target: str) -> bool:
    return re.match(
        r"^[a-zA-Z][a-zA-Z0-9+.-]*:", target
    ) is not None or target.startswith("#")


def split_link_target(target: str) -> tuple[str, str]:
    for separator in ("#", "?"):
        if separator in target:
            index = target.find(separator)
            return target[:index], target[index:]
    return target, ""


def normalize_repo_relative_path(
    chapter_path: str, link_path: str, docs_root: Path
) -> Path | None:
    chapter_fs_path = docs_root / chapter_path
    candidate = (chapter_fs_path.parent / link_path).resolve(strict=False)
    repo_root = docs_root.parent.parent

    LOGGER.debug(
        "resolve link chapter=%s link=%s chapter_fs=%s candidate=%s repo_root=%s",
        chapter_path,
        link_path,
        chapter_fs_path,
        candidate,
        repo_root,
    )

    try:
        relative = candidate.relative_to(repo_root)
    except ValueError:
        return None

    if not relative.parts or relative.parts[0] not in REPO_ROOT_NAMES:
        return None

    return relative


def build_codeberg_url(base_url: str, branch: str, repo_path: Path, suffix: str) -> str:
    encoded_path = quote(repo_path.as_posix(), safe="/")
    return f"{base_url.rstrip('/')}/src/branch/{quote(branch, safe='')}/{encoded_path}{suffix}"


def rewrite_target(
    target: str,
    chapter_path: str,
    docs_root: Path,
    src_dir: str,
    base_url: str,
    branch: str,
) -> str | None:
    if is_external_link(target):
        return None

    link_path, suffix = split_link_target(target)
    if not link_path:
        return None

    repo_path = normalize_repo_relative_path(chapter_path, link_path, docs_root)
    if repo_path is None:
        LOGGER.debug("skip unresolved link in %s: %s", chapter_path, target)
        return None

    if repo_path.suffix == "":
        LOGGER.debug(
            "skip non-file-like link in %s: %s -> %s",
            chapter_path,
            target,
            repo_path,
        )
        return None

    rewritten = build_codeberg_url(base_url, branch, repo_path, suffix)
    LOGGER.debug("rewrite link in %s: %s -> %s", chapter_path, target, rewritten)
    return rewritten


def rewrite_text(
    text: str,
    chapter_path: str,
    docs_root: Path,
    src_dir: str,
    base_url: str,
    branch: str,
) -> str:
    replacements = 0

    def replace_markdown(match: re.Match[str]) -> str:
        nonlocal replacements
        label, target = match.groups()
        rewritten = rewrite_target(
            target,
            chapter_path,
            docs_root,
            src_dir,
            base_url,
            branch,
        )
        if rewritten is None:
            return match.group(0)
        replacements += 1
        return f"[{label}]({rewritten})"

    def replace_html(match: re.Match[str]) -> str:
        nonlocal replacements
        prefix, target, middle, label, suffix = match.groups()
        rewritten = rewrite_target(
            target,
            chapter_path,
            docs_root,
            src_dir,
            base_url,
            branch,
        )
        if rewritten is None:
            return match.group(0)
        replacements += 1
        return f"{prefix}{rewritten}{middle}{label}{suffix}"

    rewritten_text = MARKDOWN_LINK_RE.sub(replace_markdown, text)
    rewritten_text = HTML_LINK_RE.sub(replace_html, rewritten_text)
    if replacements:
        LOGGER.debug("rewrote %d link(s) in %s", replacements, chapter_path)
    return rewritten_text


def process_item(
    item: object, docs_root: Path, base_url: str, branch: str, src_dir: str
) -> None:
    if not isinstance(item, dict):
        return

    chapter = item.get("Chapter")
    if chapter is None or not isinstance(chapter, dict):
        return

    chapter_path = chapter.get("path")
    if chapter_path:
        LOGGER.debug("process chapter %s", chapter_path)
        chapter["content"] = rewrite_text(
            chapter.get("content", ""),
            chapter_path,
            docs_root,
            src_dir,
            base_url,
            branch,
        )

    for sub_item in chapter.get("sub_items", []):
        process_item(sub_item, docs_root, base_url, branch, src_dir)


def process_book(
    book: dict, docs_root: Path, base_url: str, branch: str, src_dir: str
) -> None:
    items = book.get("items")
    if isinstance(items, list):
        for item in items:
            process_item(item, docs_root, base_url, branch, src_dir)
        return

    sections = book.get("sections")
    if isinstance(sections, list):
        LOGGER.debug("fallback to legacy book.sections traversal")
        for item in sections:
            process_item(item, docs_root, base_url, branch, src_dir)


def run_tests() -> None:
    class RewriteLinksTests(unittest.TestCase):
        def setUp(self) -> None:
            self.tmpdir = tempfile.TemporaryDirectory()
            self.repo_root = Path(self.tmpdir.name)
            self.docs_root = self.repo_root / "docs" / "src"
            self.chapter_path = "modules/nixos/core/activation.md"
            target_path = (
                self.repo_root / "modules" / "nixos" / "core" / "activation.nix"
            )
            target_path.parent.mkdir(parents=True)
            target_path.write_text("# activation\n")
            (self.docs_root / "modules" / "nixos" / "core").mkdir(parents=True)
            self.expected = "https://codeberg.org/Racci/nix-config/src/branch/master/modules/nixos/core/activation.nix"

        def tearDown(self) -> None:
            self.tmpdir.cleanup()

        def test_activation_relative_markdown_link_rewrites(self) -> None:
            text = "- **Entry point**: [activation.nix](../../../../../modules/nixos/core/activation.nix)"

            rewritten = rewrite_text(
                text,
                self.chapter_path,
                self.docs_root,
                "src",
                "https://codeberg.org/Racci/nix-config",
                "master",
            )

            self.assertIn(self.expected, rewritten)

        def test_activation_relative_html_link_rewrites(self) -> None:
            text = '- <strong>Entry point</strong>: <a href="../../../../../modules/nixos/core/activation.nix">activation.nix</a>'

            rewritten = rewrite_text(
                text,
                self.chapter_path,
                self.docs_root,
                "src",
                "https://codeberg.org/Racci/nix-config",
                "master",
            )

            self.assertIn(self.expected, rewritten)

        def test_process_book_items_shape(self) -> None:
            book = {
                "items": [
                    {
                        "Chapter": {
                            "path": self.chapter_path,
                            "content": "- **Entry point**: [activation.nix](../../../../../modules/nixos/core/activation.nix)",
                            "sub_items": [],
                        }
                    }
                ]
            }

            process_book(
                book,
                self.docs_root,
                "https://codeberg.org/Racci/nix-config",
                "master",
                "src",
            )

            self.assertIn(
                self.expected,
                book["items"][0]["Chapter"]["content"],
            )

    suite = unittest.defaultTestLoader.loadTestsFromTestCase(RewriteLinksTests)
    result = unittest.TextTestRunner(verbosity=2).run(suite)
    raise SystemExit(0 if result.wasSuccessful() else 1)


def main() -> None:
    if len(sys.argv) > 1 and sys.argv[1] == "supports":
        sys.exit(0)
    if len(sys.argv) > 1 and sys.argv[1] in {"test", "--test"}:
        run_tests()

    configure_logging()

    context, book = json.load(sys.stdin)
    config = context["config"]
    html = config["output"]["html"]
    preprocessor = config["preprocessor"]["rewrite-links"]

    base_url = html.get("git-repository-url")
    if not base_url:
        LOGGER.debug("skip rewrite: missing output.html.git-repository-url")
        json.dump(book, sys.stdout)
        return

    branch = preprocessor.get("git-branch", "main")
    root = Path(context.get("root", ".")).resolve(strict=False)
    book_root = Path(context.get("book", {}).get("root", ".")).resolve(strict=False)
    src_dir = config["book"].get("src", "src")
    docs_root = root / src_dir if (root / src_dir).is_dir() else book_root / src_dir

    LOGGER.debug(
        "start rewrite with branch=%s src_dir=%s docs_root=%s",
        branch,
        src_dir,
        docs_root,
    )

    process_book(book, docs_root, base_url, branch, src_dir)

    sys.stdout.write(json.dumps(book))

    sys.stdout.write("\n")
    sys.stdout.flush()


if __name__ == "__main__":
    main()
