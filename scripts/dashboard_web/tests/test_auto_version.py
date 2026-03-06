"""Tests for auto-version-bump.sh script."""

import os
import subprocess

import pytest

SCRIPT = os.path.expanduser("~/.claude/scripts/auto-version-bump.sh")


@pytest.fixture
def git_repo(tmp_path):
    """Create a temp git repo with one commit."""
    repo = tmp_path / "repo"
    repo.mkdir()
    subprocess.run(["git", "init", "-q"], cwd=str(repo), check=True)
    subprocess.run(
        ["git", "config", "user.email", "test@test.com"], cwd=str(repo), check=True
    )
    subprocess.run(["git", "config", "user.name", "Test"], cwd=str(repo), check=True)
    (repo / "file.txt").write_text("initial")
    subprocess.run(["git", "add", "."], cwd=str(repo), check=True)
    subprocess.run(
        ["git", "commit", "-q", "-m", "feat: initial feature"],
        cwd=str(repo),
        check=True,
    )
    return repo


def run_bump(repo, *extra_args):
    r = subprocess.run(
        [SCRIPT, "--repo", str(repo), "--dry-run", *extra_args],
        capture_output=True,
        text=True,
        timeout=10,
    )
    return r


class TestAutoVersionBump:
    def test_script_exists(self):
        assert os.path.isfile(SCRIPT)
        assert os.access(SCRIPT, os.X_OK)

    def test_no_tag_creates_initial_version(self, git_repo):
        r = run_bump(git_repo)
        assert r.returncode == 0
        assert "v0.1.0" in r.stdout  # feat → minor from 0.0.0

    def test_feat_bumps_minor(self, git_repo):
        subprocess.run(["git", "tag", "v1.0.0"], cwd=str(git_repo), check=True)
        (git_repo / "new.txt").write_text("new")
        subprocess.run(["git", "add", "."], cwd=str(git_repo), check=True)
        subprocess.run(
            ["git", "commit", "-q", "-m", "feat: add new feature"],
            cwd=str(git_repo),
            check=True,
        )
        r = run_bump(git_repo)
        assert "v1.1.0" in r.stdout
        assert "minor" in r.stdout

    def test_fix_bumps_patch(self, git_repo):
        subprocess.run(["git", "tag", "v2.0.0"], cwd=str(git_repo), check=True)
        (git_repo / "fix.txt").write_text("fix")
        subprocess.run(["git", "add", "."], cwd=str(git_repo), check=True)
        subprocess.run(
            ["git", "commit", "-q", "-m", "fix: resolve bug"],
            cwd=str(git_repo),
            check=True,
        )
        r = run_bump(git_repo)
        assert "v2.0.1" in r.stdout
        assert "patch" in r.stdout

    def test_breaking_bumps_major(self, git_repo):
        subprocess.run(["git", "tag", "v3.5.2"], cwd=str(git_repo), check=True)
        (git_repo / "break.txt").write_text("break")
        subprocess.run(["git", "add", "."], cwd=str(git_repo), check=True)
        subprocess.run(
            ["git", "commit", "-q", "-m", "feat!: breaking API change"],
            cwd=str(git_repo),
            check=True,
        )
        r = run_bump(git_repo)
        assert "v4.0.0" in r.stdout
        assert "major" in r.stdout

    def test_non_conventional_bumps_patch(self, git_repo):
        subprocess.run(["git", "tag", "v1.0.0"], cwd=str(git_repo), check=True)
        (git_repo / "misc.txt").write_text("misc")
        subprocess.run(["git", "add", "."], cwd=str(git_repo), check=True)
        subprocess.run(
            ["git", "commit", "-q", "-m", "update readme"],
            cwd=str(git_repo),
            check=True,
        )
        r = run_bump(git_repo)
        assert "v1.0.1" in r.stdout
        assert "patch" in r.stdout

    def test_no_commits_since_tag_exits_clean(self, git_repo):
        subprocess.run(["git", "tag", "v5.0.0"], cwd=str(git_repo), check=True)
        r = run_bump(git_repo)
        assert r.returncode == 0
        assert "Nothing to bump" in r.stdout

    def test_actual_bump_creates_tag(self, git_repo):
        subprocess.run(["git", "tag", "v1.0.0"], cwd=str(git_repo), check=True)
        (git_repo / "new.txt").write_text("new")
        subprocess.run(["git", "add", "."], cwd=str(git_repo), check=True)
        subprocess.run(
            ["git", "commit", "-q", "-m", "fix: a fix"],
            cwd=str(git_repo),
            check=True,
        )
        # Run WITHOUT --dry-run
        r = subprocess.run(
            [SCRIPT, "--repo", str(git_repo)],
            capture_output=True,
            text=True,
            timeout=10,
        )
        assert r.returncode == 0
        assert "v1.0.1" in r.stdout
        # Verify tag exists
        tags = subprocess.run(
            ["git", "tag", "-l"], cwd=str(git_repo), capture_output=True, text=True
        )
        assert "v1.0.1" in tags.stdout

    def test_actual_bump_creates_changelog(self, git_repo):
        subprocess.run(["git", "tag", "v1.0.0"], cwd=str(git_repo), check=True)
        (git_repo / "new.txt").write_text("new")
        subprocess.run(["git", "add", "."], cwd=str(git_repo), check=True)
        subprocess.run(
            ["git", "commit", "-q", "-m", "feat: new dashboard widget"],
            cwd=str(git_repo),
            check=True,
        )
        subprocess.run(
            [SCRIPT, "--repo", str(git_repo)],
            capture_output=True,
            text=True,
            timeout=10,
        )
        changelog = (git_repo / "CHANGELOG.md").read_text()
        assert "v1.1.0" in changelog
        assert "new dashboard widget" in changelog
        assert "### Added" in changelog

    def test_help_flag(self):
        r = subprocess.run(
            [SCRIPT, "--help"], capture_output=True, text=True, timeout=5
        )
        assert r.returncode == 0
        assert "Usage" in r.stdout

    def test_multiple_commits_highest_wins(self, git_repo):
        """feat > fix: if both present, minor wins over patch."""
        subprocess.run(["git", "tag", "v1.0.0"], cwd=str(git_repo), check=True)
        (git_repo / "a.txt").write_text("a")
        subprocess.run(["git", "add", "."], cwd=str(git_repo), check=True)
        subprocess.run(
            ["git", "commit", "-q", "-m", "fix: bug fix"],
            cwd=str(git_repo),
            check=True,
        )
        (git_repo / "b.txt").write_text("b")
        subprocess.run(["git", "add", "."], cwd=str(git_repo), check=True)
        subprocess.run(
            ["git", "commit", "-q", "-m", "feat: new feature"],
            cwd=str(git_repo),
            check=True,
        )
        r = run_bump(git_repo)
        assert "v1.1.0" in r.stdout
        assert "minor" in r.stdout

    def test_dotclaude_repo_dry_run(self):
        """Verify script works on the actual ~/.claude repo."""
        r = subprocess.run(
            [SCRIPT, "--repo", os.path.expanduser("~/.claude"), "--dry-run"],
            capture_output=True,
            text=True,
            timeout=10,
        )
        assert r.returncode == 0
        # Should either show a version bump or "Nothing to bump"
        assert "Version:" in r.stdout or "Nothing to bump" in r.stdout
