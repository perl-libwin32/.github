# perl-libwin32 shared release tooling

A composite GitHub Action that validates a tagged commit, builds a CPAN
distribution tarball, and attaches it to a GitHub Release. Versions with
an underscore (`0.59_01`) become pre-releases on GitHub and developer
releases on PAUSE after upload.

## Caller usage

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
      - uses: shogo82148/actions-setup-perl@<sha>
        with:
          perl-version: '5.40'
          distribution: strawberry
      - uses: perl-libwin32/.github/release-action@v1
        with:
          version-file: Win32.pm        # required
          dist-name:    Win32           # required
          # meta-file:       META.yml          # default
          # changelog-file:  Changes           # default
          # canonical-email: jan@jandubois.com # default
```

The job runs on `windows-latest` because every `Makefile.PL` in this org
gates on `$^O eq 'MSWin32' || $^O eq 'cygwin'`.

## What the action checks

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

Each module pins the action by tag (`@v1`). Composite actions resolve
bundled files via `${{ github.action_path }}`, so a caller pinned at
`@v1` always uses the script that shipped with that tag.

To roll out a change: commit, move the `v1` tag (or cut a new major),
and modules pick it up on their next release.

## Local testing

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
