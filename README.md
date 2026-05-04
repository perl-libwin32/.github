# perl-libwin32 shared CI tooling

Two pieces of org-shared CI live here:

- **`release-action/`** — composite action: validates metadata, builds the
  CPAN tarball, and attaches it to a GitHub Release.
- **`.github/workflows/test.yml`** — reusable workflow: runs the
  Strawberry-64-bit matrix, the pinned 32-bit Strawberry job, and the
  Cygwin matrix.

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
      - uses: perl-libwin32/.github/release-action@v1
        with:
          version-file: Win32.pm        # required
          dist-name:    Win32           # required
          # meta-file:       META.yml          # default
          # changelog-file:  Changes           # default
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
- The changelog has a dated entry (`<version>    [YYYY-MM-DD]`) for the tag.
- `MANIFEST` has no drift (`ExtUtils::Manifest::fullcheck`).

### Local testing

`release-action/release-checks.pl` runs standalone:

```sh
perl release-action/release-checks.pl \
  --tag v0.59 \
  --version-file Win32.pm \
  --meta-file META.yml \
  --changelog-file Changes \
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
    uses: perl-libwin32/.github/.github/workflows/test.yml@v1
    # with:
    #   test-command:        'cpanm --test-only --verbose .'   # default
    #   installdeps-command: 'cpanm --installdeps --notest .'  # default
    #   perl-versions:       '["5.32", "5.36", "5.38", "5.40"]'# default
```

Three jobs run per invocation:

- **Strawberry**: matrix over `perl-versions` (input), `windows-latest`.
- **Strawberry 32-bit**: pinned 5.38.2.1, `windows-latest`.
- **Cygwin**: matrix over `[gcc, g++]`, `windows-latest`.

The `test-command` and `installdeps-command` inputs apply to the two
Strawberry jobs. The Cygwin job hard-codes its own invocation because
the `g++` cell needs `--configure-args "CC=g++"`, which assumes
`cpanm`.

## Pinning

Each module pins the shared tooling by tag (`@v1`). For the composite
action, `${{ github.action_path }}` resolves to the action checkout at
that ref, so the bundled validation script always matches the pinned
tag. For the reusable workflow, GitHub fetches the workflow file from
the same ref.

To roll out a change: commit, move the `v1` tag (or cut a new major),
and modules pick it up on their next run.
