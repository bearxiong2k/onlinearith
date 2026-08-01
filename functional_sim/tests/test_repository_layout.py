from __future__ import annotations

import os
from pathlib import Path


FUNCTIONAL_ROOT = Path(__file__).resolve().parents[1]
REPO_ROOT = FUNCTIONAL_ROOT.parent

COMPATIBILITY_FILES = (
    "benchmarktest.py",
    "calibrate.py",
    "calibrate_base.py",
    "calibration_viz.py",
    "dist_utils.py",
    "experiment_config.py",
    "perf_viz.py",
    "ppl_batch.py",
    "ppl_batch_base.py",
    "ppl_utils.py",
    "ppltest.py",
    "qwen3test.py",
    "runtime_paths.py",
    "test_distributed.py",
    "test_fixed_sum_optimizer.py",
    "test_mxfp8linear.py",
    "visualization.py",
)

COMPATIBILITY_DIRS = ("act_base", "scripts", "tests", "tools", "wanda_base")


def _assert_relative_link(name: str) -> None:
    link = REPO_ROOT / name
    expected = Path("functional_sim") / name
    assert link.is_symlink(), f"root compatibility path must be a symlink: {link}"
    assert Path(os.readlink(link)) == expected
    assert link.resolve() == (REPO_ROOT / expected).resolve()


def test_root_compatibility_files_are_relative_symlinks() -> None:
    for name in COMPATIBILITY_FILES:
        _assert_relative_link(name)


def test_root_compatibility_directories_are_relative_symlinks() -> None:
    for name in COMPATIBILITY_DIRS:
        _assert_relative_link(name)


def test_canonical_functional_root_is_nested() -> None:
    assert (FUNCTIONAL_ROOT / "experiment_config.py").is_file()
    assert (FUNCTIONAL_ROOT / "scripts").is_dir()
    assert (FUNCTIONAL_ROOT / "tools").is_dir()
    assert (FUNCTIONAL_ROOT / "tests").is_dir()
    assert FUNCTIONAL_ROOT.parent == REPO_ROOT
