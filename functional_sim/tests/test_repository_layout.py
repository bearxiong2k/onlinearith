from __future__ import annotations

from pathlib import Path


FUNCTIONAL_ROOT = Path(__file__).resolve().parents[1]
REPO_ROOT = FUNCTIONAL_ROOT.parent

FUNCTIONAL_DIRS = ("act_base", "scripts", "tests", "tools", "wanda_base")


def _assert_retired_root_path_absent(name: str) -> None:
    path = REPO_ROOT / name
    assert not path.exists(), f"functional root alias must stay absent: {path}"
    assert not path.is_symlink(), f"broken functional root alias must stay absent: {path}"


def test_functional_python_files_have_no_root_aliases() -> None:
    for path in FUNCTIONAL_ROOT.glob("*.py"):
        _assert_retired_root_path_absent(path.name)


def test_functional_directories_have_no_root_aliases() -> None:
    for name in FUNCTIONAL_DIRS:
        _assert_retired_root_path_absent(name)


def test_canonical_functional_root_is_nested() -> None:
    assert (FUNCTIONAL_ROOT / "experiment_config.py").is_file()
    assert (FUNCTIONAL_ROOT / "scripts").is_dir()
    assert (FUNCTIONAL_ROOT / "tools").is_dir()
    assert (FUNCTIONAL_ROOT / "tests").is_dir()
    assert FUNCTIONAL_ROOT.parent == REPO_ROOT
