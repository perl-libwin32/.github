# perl-libwin32 shared workflows

Reusable GitHub Actions workflows for the Perl Win32 modules under this org.

## `.github/workflows/release.yml`

Validates a tagged commit, builds a CPAN distribution tarball, and attaches it
to a GitHub Release. Treats versions with an underscore (`0.59_01`) as CPAN
developer releases and marks the GitHub Release as a pre-release.

Caller usage:

```yaml
name: release
on:
  push:
    tags: ['v*']
jobs:
  release:
    uses: perl-libwin32/.github/.github/workflows/release.yml@v1
    with:
      version-file: Win32.pm        # required
      dist-name:    Win32           # required
      # meta-file:       META.yml          # default
      # changelog-file:  Changes           # default
      # canonical-email: jan@jandubois.com # default
      # perl-version:    '5.40'            # default
    permissions:
      contents: write
```

The workflow runs on `windows-latest` with Strawberry Perl, because every
`Makefile.PL` in this org gates on `$^O eq 'MSWin32' || $^O eq 'cygwin'`.

## What the validation step checks

Hard fails (block the release):

- Tag, source `$VERSION`, and `META.yml` `version` all agree.
- `META.yml` `name` matches the `dist-name` input.
- `META.yml` declares a license other than `unknown` and a non-empty abstract.
- An author entry contains the canonical email; no entry uses `@activestate.com`.
- `META.yml` `resources.repository` matches the GitHub repo URL.
- The changelog has a dated entry (`<version>    [YYYY-MM-DD]`) for the tag.
- `MANIFEST` has no drift (`ExtUtils::Manifest::fullcheck`).

Soft warning:

- `META.yml` `resources.bugtracker` missing.

## Pinning

Each module pins the workflow by tag (`@v1`). The reusable workflow checks out
this repo at `${{ github.workflow_sha }}` to fetch the validation script, so a
caller pinned at `@v1` always gets the script that shipped with that tag.

To roll out a change: commit, move the `v1` tag (or cut a new major), and the
modules pick it up on their next release.
