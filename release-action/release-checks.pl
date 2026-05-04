#!/usr/bin/perl
use strict;
use warnings;
use Getopt::Long;
use CPAN::Meta;
use ExtUtils::Manifest qw(fullcheck);

GetOptions(
    'tag=s'             => \my $tag,
    'version-file=s'    => \my $version_file,
    'meta-file=s'       => \my $meta_file,
    'changelog-file=s'  => \my $changelog_file,
    'dist-name=s'       => \my $dist_name,
    'canonical-email=s' => \my $canonical_email,
    'expected-repo=s'   => \my $expected_repo,
) or die usage();

for my $req (
    [tag                => $tag],
    ['version-file'     => $version_file],
    ['meta-file'        => $meta_file],
    ['changelog-file'   => $changelog_file],
    ['dist-name'        => $dist_name],
    ['canonical-email'  => $canonical_email],
    ['expected-repo'    => $expected_repo],
) {
    my ($name, $value) = @$req;
    die "missing required --$name\n" unless defined $value && length $value;
}

my @errors;

(my $tag_version = $tag) =~ s/^v//;
push @errors, "tag '$tag' does not look like a version (expected vX.YZ or vX.YZ_NN)"
    unless $tag_version =~ /^[0-9]+(?:\.[0-9]+)?(?:_[0-9]+)?$/;

my $source_version = extract_source_version($version_file);
if (!defined $source_version) {
    push @errors, "could not find \$VERSION assignment in $version_file";
}
elsif ($source_version ne $tag_version) {
    push @errors, "version mismatch: tag=$tag_version but $version_file has $source_version";
}

my $meta = eval { CPAN::Meta->load_file($meta_file) };
if (!$meta) {
    push @errors, "could not load $meta_file: $@";
}
else {
    push @errors, "version mismatch: tag=$tag_version but $meta_file has " . $meta->version
        if $meta->version ne $tag_version;

    push @errors, "$meta_file name=" . $meta->name . " but expected $dist_name"
        if $meta->name ne $dist_name;

    my @licenses = $meta->licenses;
    push @errors, "$meta_file license is missing or 'unknown'"
        if !@licenses || (@licenses == 1 && $licenses[0] eq 'unknown');

    push @errors, "$meta_file abstract is missing"
        unless $meta->abstract;

    my @authors = $meta->authors;
    push @errors, "no $meta_file author entry contains $canonical_email"
        unless grep { /\Q$canonical_email\E/ } @authors;
    push @errors, "$meta_file author entry still uses \@activestate.com (replace with $canonical_email)"
        if grep { /\@activestate\.com/i } @authors;

    my $resources = $meta->resources || {};
    my $repo_meta = $resources->{repository};
    my $repo_url = ref($repo_meta) eq 'HASH'
        ? ($repo_meta->{url} || $repo_meta->{web})
        : $repo_meta;
    if (!$repo_url) {
        push @errors, "$meta_file resources.repository is missing";
    }
    else {
        (my $normalised = $repo_url) =~ s{\.git$}{};
        $normalised =~ s{/$}{};
        push @errors, "$meta_file resources.repository=$repo_url but expected $expected_repo"
            if lc $normalised ne lc $expected_repo;
    }

    my $bug = $resources->{bugtracker};
    my $bug_url = ref($bug) eq 'HASH' ? ($bug->{web} || $bug->{mailto}) : $bug;
    my $expected_bug = "$expected_repo/issues";
    if (!$bug_url) {
        push @errors, "$meta_file resources.bugtracker is missing (expected $expected_bug)";
    }
    else {
        (my $normalised_bug = $bug_url) =~ s{/$}{};
        push @errors, "$meta_file resources.bugtracker=$bug_url but expected $expected_bug"
            if lc $normalised_bug ne lc $expected_bug;
    }
}

push @errors, "no dated entry for $tag_version in $changelog_file"
    . " (expected line matching: $tag_version    [YYYY-MM-DD])"
    unless check_changelog_entry($changelog_file, $tag_version);

local $ExtUtils::Manifest::Quiet = 1;
my ($missing, $extra) = fullcheck();
push @errors, "listed in MANIFEST but missing from disk: $_" for @$missing;
push @errors, "on disk but not listed in MANIFEST: $_"       for @$extra;

warn "::error::$_\n" for @errors;
exit(@errors ? 1 : 0);

sub extract_source_version {
    my ($file) = @_;
    open my $fh, '<:raw', $file or die "open $file: $!\n";
    while (<$fh>) {
        return $1 if /^\s*(?:our\s+)?\$VERSION\s*=\s*['"]([\d._]+)['"]/;
    }
    return undef;
}

sub check_changelog_entry {
    my ($file, $version) = @_;
    open my $fh, '<:raw', $file or die "open $file: $!\n";
    my $pat = quotemeta($version);
    while (<$fh>) {
        return 1 if /^${pat}\s+\[\d{4}-\d{2}-\d{2}\]/;
    }
    return 0;
}

sub usage {
    return <<'USAGE';
Usage: release-checks.pl --tag VTAG --version-file FILE --meta-file FILE \
       --changelog-file FILE --dist-name NAME --canonical-email EMAIL \
       --expected-repo URL

Validates that a Perl distribution is ready to release at the given tag.
Exits non-zero on any hard-fail check.
USAGE
}
