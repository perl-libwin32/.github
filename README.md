# perl-libwin32 shared CI tooling

Two pieces of org-shared CI live here:

- **`release-action/`** — composite action: validates metadata, builds the
  CPAN tarball, and attaches it to a GitHub Release.
- **`.github/workflows/test.yml`** — reusable workflow: runs the
  64-bit Strawberry matrix, the pinned 32-bit Strawberry job, the UTF-8
  ACP and MSVC jobs, and the Cygwin matrix.

## Release action

Versions with an underscore (`0.59_01`) become pre-releases on GitHub and
developer releases on PAUSE after upload.

### Caller usage

```yaml
name: release
on:
  push:
    tags: ['v*']
jobs:
  release:
    runs-on: windows-latest
    permissions:
      contents: write
    steps:
      - uses: actions/checkout@<sha>
      - uses: perl-libwin32/.github/release-action@v2
        with:
          version-file: Win32.pm        # required
          dist-name:    Win32           # required
          # meta-file:       META.yml          # default
          # changelog-file:  CHANGES.md        # default
          # canonical-email: jan@jandubois.com # default
          # perl-version:    '5.40'            # default
```

The job runs on `windows-latest` because every `Makefile.PL` in this org
gates on `$^O eq 'MSWin32' || $^O eq 'cygwin'`.

### What the action checks

Hard fails (block the release):

- Tag, source `$VERSION`, and `META.yml` `version` all agree.
- `META.yml` `name` matches the `dist-name` input.
- `META.yml` declares a license other than `unknown` and a non-empty abstract.
- An author entry contains the canonical email; no entry uses `@activestate.com`.
- `META.yml` `resources.repository` matches the GitHub repo URL.
- `META.yml` `resources.bugtracker` matches `<repo URL>/issues`.
- The changelog has a dated Markdown header (`## <version> [YYYY-MM-DD]`) for the tag.
- `MANIFEST` has no drift (`ExtUtils::Manifest::fullcheck`).

### Local testing

`release-action/release-checks.pl` runs standalone:

```sh
perl release-action/release-checks.pl \
  --tag v0.59 \
  --version-file Win32.pm \
  --meta-file META.yml \
  --changelog-file CHANGES.md \
  --dist-name Win32 \
  --canonical-email jan@jandubois.com \
  --expected-repo https://github.com/perl-libwin32/win32
```

## Test workflow

### Caller usage

```yaml
name: test
on:
  push:
    branches: [master]
  pull_request:
  workflow_dispatch:
jobs:
  test:
    uses: perl-libwin32/.github/.github/workflows/test.yml@v2
    # with:
    #   test-command:        'cpanm --test-only --verbose .'   # default
    #   installdeps-command: 'cpanm --installdeps --notest .'  # default
    #   perl-versions:       '["5.32", "5.36", "5.38", "5.40"]'# default
```

These jobs run per invocation:

- **Strawberry**: matrix over `perl-versions` (input), `windows-latest`.
- **Strawberry 32-bit**: pinned 5.38.2.1, `windows-latest`.
- **UTF-8 ACP**: Strawberry 5.40 with the UTF-8 code page enabled in
  `perl.exe`, `windows-latest`.
- **MSVC**: conda-forge's Perl 5.44, built with Visual C++ against the
  Universal CRT, `windows-latest`. Only `@v2` has this job.
- **Cygwin**: matrix over `[gcc, g++]`, `windows-latest`.

The `test-command` and `installdeps-command` inputs apply to every job
except Cygwin. The Cygwin job hard-codes its own invocation because
the `g++` cell needs `--configure-args "CC=g++"`, which assumes
`cpanm`.

## Pinning

Each module pins the shared tooling by tag. The release action is at
`@v2`, and so is the test workflow. For the composite action,
`${{ github.action_path }}` resolves to the action checkout at that
ref, so the bundled validation script always matches the pinned tag.
For the reusable workflow, GitHub fetches the workflow file from the
same ref.

Don't call `test.yml@v1`. Its Cygwin jobs fail while installing
Cygwin, because the version of `cygwin-install-action` that `v1` pins
rejects the certificate that Cygwin now signs its installer with.

To roll out a non-breaking change: commit, move the current major tag,
and modules pick it up on their next run. To roll out a breaking
change: commit, tag a new major (`v3`, etc.), and migrate each module
explicitly.

### v2 release-action migration

`v2` requires the changelog file to be Markdown (defaulting to
`CHANGES.md`) with `## <version> [YYYY-MM-DD]` headers. The legacy
flat format that `v1` accepted (`<version>    [YYYY-MM-DD]`) no
longer validates. Each module migrates on its own schedule:

1. Rename `Changes` to `CHANGES.md`.
2. Add `# Revision history for <Module>` at the top.
3. Prefix every existing version line with `## `.
4. Rewrite `[PR/N]` references as full-URL Markdown links
   (`[#N](https://github.com/perl-libwin32/<repo>/pull/N)`). GitHub
   auto-links bare `#N` only on Release pages and in issue comments,
   not in rendered Markdown files like `CHANGES.md`.
5. Update `MANIFEST` (`Changes` → `CHANGES.md`).
6. Bump `.github/workflows/release.yml` from `@v1` to `@v2`.
