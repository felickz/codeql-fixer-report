<#
.SYNOPSIS
    This script retrieves the CodeQL workflow runs for repositories in a specified GitHub organization and generates a summary report in Markdown format.

.DESCRIPTION
    The report includes the conclusion, workflow URL, whether the workflow is the default one, organization name, repository name, and workflow path. The script also checks if the FormatMarkdownTable module is installed and installs it if necessary. Finally, it converts the summary report to Markdown format and outputs it to the GITHUB_STEP_SUMMARY environment variable. If the script is not running in a GitHub Actions environment, it also outputs the summary report to the console.

.PARAMETER GitHubToken
    The GitHub PAT that is used to authenticate to GitHub GH CLI (uses the envioronment value GH_TOKEN).

.PARAMETER GitHubOrganization
    The GitHub organization that the script will operate on. Defaults to the current Organization if not provided.

.PARAMETER GitHubRepository
    The GitHub repository that the script will operate on. Defaults to the current Repository if not provided.

.EXAMPLE
    .\action.ps1 -GitHubToken "your_token_here" -GitHubOrganization "your_organization_here" -GitHubRepository "your_repository_here"
    
    .\action.ps1 -GitHubToken (gh auth token) -GitHubOrganization "octodemo" -GitHubRepository "old-vulnerable-node"

.NOTES
    Be careful not to expose your GitHub PAT in your workflow or any public places because it can be used to access your GitHub account.

.LINK
    For more information about GitHub Actions, visit: https://docs.github.com/en/actions.
    For information about composite actions, visit: https://docs.github.com/en/actions/creating-actions/creating-a-composite-action.
    For information about the GH CLI, visit: https://cli.github.com/manual/gh_api.

#>

param(
    [string]$GitHubToken,
    [string]$GitHubOrganization,
    [string]$GitHubRepository
)

# set the GH_TOKEN environment variable to the value of the GitHubToken parameter
if (![String]::IsNullOrWhiteSpace($GitHubToken)) {
    $env:GH_TOKEN = $GitHubToken
}

# Set GitHubOrganization from GITHUB_REPOSITORY_OWNER environment variable if not already set
if ([String]::IsNullOrWhiteSpace($GitHubOrganization)) {
    if ($null -ne $env:GITHUB_REPOSITORY_OWNER) {
        $GitHubOrganization = $env:GITHUB_REPOSITORY_OWNER
    }
}

# Set GitHubRepository from GITHUB_REPOSITORY environment variable if not already set
if ([String]::IsNullOrWhiteSpace($GitHubRepository)) {
    if ($null -ne $env:GITHUB_REPOSITORY) {
        # GITHUB_REPOSITORY is in the format "owner/repo", we just need the repo part
        $GitHubRepository = $env:GITHUB_REPOSITORY.Split('/')[1]
    }
}

$nwo = "$GitHubOrganization/$GitHubRepository"
$state = "fixed" # NOTE - fixed means alert was not present in a subsequent scan - which might introduce noise if a code scanning config was removed
$alerts = gh api "/repos/$nwo/code-scanning/alerts?state=$state&tool_name=CodeQL" --paginate | ConvertFrom-Json

# Loop through each alert and build a list of users who fixed them and keep a count
$commitCache = @{}
$fixers = @{}
foreach ($alert in $alerts) {    
    # Get the commit details from cache or API
    $sha = $alert.most_recent_instance.commit_sha
    if (-not $commitCache.ContainsKey($sha)) {
        $commitCache[$sha] = gh api "/repos/$nwo/git/commits/$sha" | ConvertFrom-Json
    }

    $commit = $commitCache[$sha]
    $author = $commit.author.name
    $email = $commit.author.email
    #Write-Host "#$($alert.number) - $($alert.state) RULE:$($alert.rule.id) SHA:$sha Author: $($commit.author.name) Date:$($commit.author.date)"

    if ($fixers.ContainsKey($author)) {
        $fixers[$author].Count++
    }
    else {
        $fixers[$author] = @{
            Count = 1
            Email = $email
            Org = $GitHubOrganization
            Repo = $GitHubRepository
        }
    }
}

$csv = "CodeQLFixersReport.csv"
$header = "Author,Email,Org,Repo,NumFixes"
Set-Content -Path "./$csv" -Value $header

# Write results to CSV file
foreach ($author in $fixers.Keys) {
    $line = "$author,$($fixers[$author].Email),$($fixers[$author].Org),$($fixers[$author].Repo),$($fixers[$author].Count)"
    Add-Content -Path "./$csv" -Value $line
}

#TODO move to a manifest like choco package.config
if (Get-Module -ListAvailable -Name FormatMarkdownTable -ErrorAction SilentlyContinue) {
    Write-Host "FormatMarkdownTable module is installed"
}
else {
    # Handle `Untrusted repository` prompt
    Set-PSRepository PSGallery -InstallationPolicy Trusted
    #directly to output here before module loaded to support Write-ActionInfo
    Write-Host "FormatMarkdownTable module is not installed.  Installing from Gallery..."
    Install-Module -Name FormatMarkdownTable
}

# Create a header for the markdown report
$reportHeader = "# CodeQL Fixers Report`n`n"
$reportHeader += "This report shows users who have fixed CodeQL alerts in repository $nwo.`n`n"

# Generate the markdown table and add the header
$markdownTable = Import-Csv -Path "./$csv" | Format-MarkdownTableTableStyle -ShowMarkdown -DoNotCopyToClipboard -HideStandardOutput
$markdownSummary = $reportHeader + $markdownTable

$markdownSummary > $env:GITHUB_STEP_SUMMARY

if ($null -eq $env:GITHUB_ACTIONS) {
    $markdownSummary
}