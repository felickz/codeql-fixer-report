# felickz/codeql-fixer-report GitHub Action

This action allows you to generate a CodeQL fixer report.

This action queries the CodeQL API to get a list of users who are fixing alerts in your repositories, producing a CSV report that summarizes the number of fixes by each developer.

## Usage

To use the `felickz/codeql-fixer-report` action, you need to set it up in a workflow file (`.github/workflows/codeql-fixer-report.yml`).

Here's a basic example:

```yaml
name: CodeQL Report

on:
  push:
    paths:
      - '.github/workflows/codeql-fixer-report.yml'
  workflow_dispatch:
  #every 12 hours
  schedule:
    - cron: '0 */12 * * *'

jobs:
  run-report:
    runs-on: ubuntu-latest
    permissions:
      contents: read
      security-events: read

    steps:
    - name: Use felickz/codeql-fixer-report action
      uses: felickz/codeql-fixer-report@main
      with:
        token: ${{ secrets.GITHUB_TOKEN }}
    - name: Upload CodeQL Report CSV as Artifact
      uses: actions/upload-artifact@v4
      with:
        name: "CodeQLFixersReport-${{ github.run_id }}"
        path: ./*.csv
```

In this example, the felickz/codeql-fixer-report action is used from the `main` branch directly.  The report is run every 12 hours via cron schedule.

The github-token input is required for the felickz/codeql-fixer-report action. It uses the GITHUB_TOKEN secret, which would need to have `contents: read` and `security-events: read` permissions for your organization for any private repos.

The `upload-artfact` action is used to create the CSV attached to the action workflow summary.

## Inputs
### token
Required The GitHub token to authenticate and pull CodeQL Action workflow status with. Needs to have `contents: read` and `security-events: read` permissions for your organization's private repos.

### organization
Optional The GitHub Organization. Defaults to the current Organization.

### repository
Optional The GitHub Repository. Defaults to the current Repository from the workflow context.