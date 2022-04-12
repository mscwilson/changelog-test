# Release Helper
```
As a member of the DV Trackers team, I want to automate some of the release process, to maximise time to do important stuff. 
``` 

The current version is v0.3.0.

- [Release Helper](#release-helper)
  - [Prepare for release](#prepare-for-release)
    - [CHANGELOG](#changelog)- [Release Helper](#release-helper)
  - [Prepare for release](#prepare-for-release)
    - [CHANGELOG](#changelog)
    - [Version strings](#version-strings)
  - [Release notes creation](#release-notes-creation)
  - [Using the Action](#using-the-action)
    - [Input options](#input-options)
    - [Output](#output)
    - [Example workflow: Prepare for release](#example-workflow-prepare-for-release)
    - [Example workflow: Release (notes and release)](#example-workflow-release-notes-and-release)
    - [Version strings](#version-strings)
  - [Release notes creation](#release-notes-creation)
  - [Using the Action](#using-the-action)
    - [Input options](#input-options)
    - [Output](#output)
    - [Example workflow: Prepare for release](#example-workflow-prepare-for-release)
    - [Example workflow: Release (notes and release)](#example-workflow-release-notes-and-release)

This Action automates different parts of the release process. Currently, this is separated into two operations:

**Prepare for release/CHANGELOG creation** When a "release/x.x.x" branch is opened to `main` (or `master`), it updates and commits the CHANGELOG file. Also, all the version numbers in the project can be updated to the new version, if an appropriate file is provided. 

**Release notes** As part of the standard release/deploy workflow. When the `main` branch is tagged for release, it creates and outputs release notes, which can be provided to the Github Release action (softprops/action-gh-release). The release notes are made of the PR description plus commits sorted by their issue labels.

## Prepare for release
This operation must be specified in the workflow with the input "prepare for release" or "prepare". It will only run on a PR from a "release/{{ version }}" branch to `main`/`master`.

The new files are committed with the message "Prepare for {{ version }} release".

### CHANGELOG
A basic CHANGELOG section looks like this:
```
Version 0.2.0 (2022-02-01)
-----------------------
Publish Gradle module file with bintrayUpload (#255)
Update snyk integration to include project name in GitHub action (#8) - thanks @ExternalPerson!
```
This Action gets the version number from the name of the release branch: "Release/{{ version }}" or "release/{{ version }}". The date is today's date.

The commits are all the commits on the release branch, up until the "Prepare for {{ previous }} release" commit, excluding any without issue numbers. 

If the commit was authored by someone not in the "snowplow" organisation, then it's from an external contributor. Their username is added to thank them.

### Version strings
A repo could have the current version written in several places, e.g. the version file, throughout the README, tests, etc.

Optionally provide a JSON file detailing all these locations - file paths plus a string containing the version for context. This will make sure only the correct strings are changed.

The version numbers must be X'd out: "x.x.x" or "X.X.X". This will work for any release, including pre-releases like "1.2.3-alpha.0". The Action won't fail if they're not X'd out, it will commit unchanged files.  

All occurrances of the same provided string within a file will be updated.

For example:
```json
{
  "lib/version.rb": "repo_version = \"x.x.x\"",
  "README.md": [
    "latest release was version X.X.X",
    "Yes, vx.x.x has a pleasing symmetry",
    "gem \"try-out-actions-here\", \"x.x.x\""
  ]
}
```
Provide the path to this locations file as an Action input. See below for details.

## Release notes creation
This operation must be specified in the workflow with the input "github release notes" or "github". It will only run on a tag event.

The assumption is that the release workflow is triggered by manually tagging the "Prepare for {{ previous }} release" commit on `main`/`master`.

Example release notes:  

> We are pleased to announce version 1.2.3. It does loads of cool stuff.
> 
> The main new feature is really good.
> 
>**New features**  
> Add an amazing new feature (#1) **BREAKING CHANGE**  
> Track a new kind of event (#4) - thanks @ExternalPerson! **BREAKING CHANGE**  
> Output winning lottery numbers (#6)  
> 
> **Bug fixes**  
> Fix events being randomly deleted (#8)  
> 
> **Under the hood**  
> Remove secret keys (#5)  

The text body is the description from the PR.

The commits are the ones in between the "Prepare for x release" commits on the `main` (or `master`) branch. They're sorted based on their issue labels: "type:enhancement", "type:defect", or "type:admin". Issues without one of those will be under the heading **Changes**.

Commits are labelled "breaking change" if the issue had the "category:breaking_change" label.

As above for CHANGELOG, external contributions are determined based on membership of "snowplow" org.


## Using the Action
Use the Release Helper in a job like this:
```yaml
steps:
  - uses: actions/checkout@v2
    with:
      repository: mscwilson/changelog-creator

  - uses: ruby/setup-ruby@v1
    with:
      bundler-cache: true

  - name: Update version strings and CHANGELOG
    id: release-notes
    uses: mscwilson/changelog-creator@0.3.0
    with:
      operation: "prepare" # or "github" - must specify an operation
    env:
      ACCESS_TOKEN: ${{ secrets.GITHUB_TOKEN }}
```
This is a Composite action written in Ruby, it requires multiple steps to a) checkout the Action repo, b) set up Ruby and install the gems, c) do the Action. 

The Action uses the Github API Octokit wrapper. It requires the GITHUB_TOKEN for auth.

### Input options
```yaml
- uses: mscwilson/changelog-creator@0.3.0
  with:
    # What you want the action to do. Must be one of these choices:
    # Update files? "prepare for release" (or "prepare")
    # Generate release notes? "github release notes" (or "github")
    # 
    # Required!
    operation: ''

    # Optional file location for an versions-updating helper file. 
    # The file should contain a list of file paths and strings to update. 
    # "X" out the version numbers.
    # Only relevant for operation "prepare for release".
    # 
    # Optional.
    version_script_path: ''
```

### Output
There is one output, called `release-notes`.

It is base64-encoded. If the Action has successfully performed "github release notes", the `release-notes` output will be the encoded PR description plus commits. 

Most of the time, the Action will output encoded "No release notes needed!".

### Example workflow: Prepare for release
```yaml
name: "Prepare for release"

on: [pull_request]

# Give the Action permission
permissions:
  contents: write

jobs:
  prepare-for-release:
    runs-on: ubuntu-latest
    # Include this conditional if the workflow is running on other event types too, e.g. "push"
    # if: github.event_name == 'pull_request'

    steps:
      - uses: actions/checkout@v2
        with:
          repository: mscwilson/changelog-creator

      - uses: ruby/setup-ruby@v1
        with:
          bundler-cache: true

      - name: Update version strings and CHANGELOG
        uses: mscwilson/changelog-creator@0.3.0
        with:
          operation: "prepare"
          version_script_path: ".github/workflows/version_locations.json"
        env:
          ACCESS_TOKEN: ${{ secrets.GITHUB_TOKEN }}
```

### Example workflow: Release (notes and release)
```yaml
name: Deploy

on:
  push:
    tags:
      - "*"

jobs:
  prepare-to-publish:
    # This job should check it's ok to continue with the release
    # 1. Make sure the tag version matches the repo version
    # Exit with error if it's not
    # 2. Save the current version number as an output

    runs-on: ubuntu-latest
    outputs:
      gem-version: ${{ steps.gem-version.outputs.gem-version }}

    steps:
      - name: Checkout
        uses: actions/checkout@v2

      - name: Get tag and tracker version information
        id: version
        # Getting the tracker/project version will be different for each repo
        run: |
          echo ::set-output name=TAG_VERSION::${GITHUB_REF#refs/*/}
          echo "##[set-output name=TRACKER_VERSION;]$(grep -oE "[0-9]+\.[0-9]+\.[0-9]+-?[a-z]*\.?[0-9]*" lib/version.rb)"
    
      - name: Fail if version mismatch
        if: ${{ steps.version.outputs.TAG_VERSION != steps.version.outputs.TRACKER_VERSION }}
        run: |
          echo "Tag version (${{ steps.version.outputs.TAG_VERSION }}) doesn't match version in project (${{ steps.version.outputs.TRACKER_VERSION }})"
          exit 1

  release-notes:
    # Require "prepare-to-publish" job so the jobs run sequentially
    needs: prepare-to-publish
    runs-on: ubuntu-latest
    # Save the output for this job
    outputs:
      release-notes: ${{ steps.notes.outputs.release-notes }}

    steps:
      - uses: actions/checkout@v2
        with:
          repository: mscwilson/changelog-creator

      - uses: ruby/setup-ruby@v1
        with:
          bundler-cache: true

      - name: Create release notes
        id: notes
        uses: mscwilson/changelog-creator@0.3.0
        with:
          operation: "github"
        env:
          ACCESS_TOKEN: ${{ secrets.GITHUB_TOKEN }}

  publish:
    # Require "release-notes" to be able to access the output via "needs"
    needs: [prepare-to-publish, release-notes]
    runs-on: ubuntu-latest

    steps:
      - name: Checkout
        uses: actions/checkout@v2

      - name: Save release notes to file
        # The Release Helper output must be base64-decoded
        # before it can be provided to softprops/action-gh-release
        run: |
          echo ${{ needs.release-notes.outputs.release-notes }} | base64 --decode > notes.txt

      - name: Release on GitHub
        uses: softprops/action-gh-release@v0.1.12
        with:
          name: Version ${{ needs.prepare-to-publish.outputs.gem-version }}
          prerelease: ${{ contains(needs.prepare-to-publish.outputs.gem-version, '-') }}
          body_path: notes.txt
        env:
          GITHUB_TOKEN: ${{ secrets.GITHUB_TOKEN }}
```
