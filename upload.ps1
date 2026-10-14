<#
.SYNOPSIS
    Upload files to github.com/amittal2026/file_upload.

.DESCRIPTION
    Collaborators: files are committed directly to the repository.
    Everyone else: files go to your fork and a pull request is opened for review.

    Requires git (https://git-scm.com) and GitHub CLI (https://cli.github.com).

.PARAMETER Path
    One or more files or folders to upload.

.PARAMETER Folder
    Folder in the repository to upload into. Default: repository root.

.PARAMETER Message
    Short description of the upload. Default: "Upload N item(s)".

.EXAMPLE
    .\upload.ps1 report.pdf

.EXAMPLE
    .\upload.ps1 -Folder acme-ltd -Message "Q3 documents" report.pdf .\scans
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory = $true, Position = 0, ValueFromRemainingArguments = $true)]
    [string[]]$Path,
    [string]$Folder = "",
    [string]$Message = ""
)

$Repo      = 'amittal2026/file_upload'
$MaxBytes  = 100MB   # GitHub rejects files over 100 MB
$WarnBytes = 50MB

function Info($msg) { Write-Host "==> $msg" -ForegroundColor Cyan }

# Run a native command and stop if it fails.
function Invoke-Checked {
    $exe, $rest = $args
    & $exe @rest
    if ($LASTEXITCODE -ne 0) { throw "Command failed: $exe $($rest -join ' ')" }
}

$exitCode = 0
$work = $null

try {
    if (-not (Get-Command git -ErrorAction SilentlyContinue)) {
        throw "git is not installed. Install it with: winget install Git.Git  (then open a new PowerShell window)"
    }
    if (-not (Get-Command gh -ErrorAction SilentlyContinue)) {
        throw "GitHub CLI (gh) is not installed. Install it with: winget install GitHub.cli  (then open a new PowerShell window)"
    }

    # --- Check inputs and file sizes ---------------------------------------
    $items = @()
    foreach ($p in $Path) {
        if (-not (Test-Path -LiteralPath $p)) { throw "Not found: $p" }
        $items += (Resolve-Path -LiteralPath $p).ProviderPath.TrimEnd('\', '/')
    }

    foreach ($f in (Get-ChildItem -LiteralPath $items -Recurse -File -Force)) {
        if ($f.Length -gt $MaxBytes) {
            throw "$($f.FullName) is larger than 100 MB, which GitHub does not accept. Split it into smaller parts or contact the repository owner."
        } elseif ($f.Length -gt $WarnBytes) {
            Write-Warning "$($f.FullName) is over 50 MB; the upload may be slow."
        }
    }

    if (-not $Message) { $Message = "Upload $($items.Count) item(s)" }
    $Folder = $Folder.Replace('\', '/').Trim('/')

    # --- Sign in to GitHub (first run only) --------------------------------
    gh auth status --hostname github.com *> $null
    if ($LASTEXITCODE -ne 0) {
        Info "Sign in to GitHub (one-time). Follow the prompts."
        Invoke-Checked gh auth login --hostname github.com --git-protocol https --web
    }
    gh auth setup-git --hostname github.com *> $null

    $me    = gh api user --jq .login
    $myId  = gh api user --jq .id
    $base  = gh api "repos/$Repo" --jq .default_branch
    if ($LASTEXITCODE -ne 0) { throw "Can't access $Repo. Check the repository name and your access." }
    $canPush = gh api "repos/$Repo" --jq '.permissions.push // false'

    # --- Prepare a temporary working copy ----------------------------------
    $work = Join-Path ([IO.Path]::GetTempPath()) ("file_upload_" + [guid]::NewGuid().ToString('N'))
    New-Item -ItemType Directory -Path $work | Out-Null
    $r = Join-Path $work 'repo'

    Info "Preparing upload..."
    # Partial, sparse clone: downloads history metadata, not every existing file.
    Invoke-Checked git clone --quiet --filter=blob:none --sparse "https://github.com/$Repo.git" $r
    Invoke-Checked git -C $r config user.name $me
    Invoke-Checked git -C $r config user.email "$myId+$me@users.noreply.github.com"
    Invoke-Checked git -C $r config core.autocrlf false   # keep files byte-for-byte identical

    $target = $r
    if ($Folder) {
        Invoke-Checked git -C $r sparse-checkout add $Folder
        $target = Join-Path $r $Folder
    } else {
        foreach ($item in $items) {
            if (Test-Path -LiteralPath $item -PathType Container) {
                Invoke-Checked git -C $r sparse-checkout add (Split-Path $item -Leaf)
            }
        }
    }
    New-Item -ItemType Directory -Path $target -Force | Out-Null

    foreach ($item in $items) {
        Copy-Item -LiteralPath $item -Destination $target -Recurse -Force
    }

    Invoke-Checked git -C $r add -A
    git -C $r diff --cached --quiet
    if ($LASTEXITCODE -eq 0) { throw "Nothing to upload: these files are already in the repository, unchanged." }
    Invoke-Checked git -C $r commit --quiet -m $Message

    # --- Upload ------------------------------------------------------------
    if ($canPush -eq 'true') {
        Info "Uploading directly (you are a collaborator)..."
        git -C $r push --quiet origin "HEAD:$base"
        if ($LASTEXITCODE -ne 0) {
            # Someone else uploaded in the meantime: catch up and try again.
            Invoke-Checked git -C $r pull --quiet --rebase origin $base
            Invoke-Checked git -C $r push --quiet origin "HEAD:$base"
        }
        $url = "https://github.com/$Repo/tree/$base"
        if ($Folder) { $url += "/$Folder" }
        Write-Host ""
        Write-Host "Done. Your files are at: $url" -ForegroundColor Green
    } else {
        Info "Submitting for review via your fork..."
        $fork = gh api -X POST "repos/$Repo/forks" --jq .full_name   # returns the existing fork if you have one
        if ($LASTEXITCODE -ne 0 -or -not $fork) { throw "Could not create a fork of $Repo." }
        $forkOwner = $fork.Split('/')[0]
        gh repo sync $fork --branch $base *> $null   # best effort; fine if it fails

        $branch = "upload-" + (Get-Date -Format 'yyyyMMdd-HHmmss')
        Invoke-Checked git -C $r remote add fork "https://github.com/$fork.git"

        # A brand-new fork can take a few seconds to become ready.
        $pushed = $false
        for ($i = 0; $i -lt 6; $i++) {
            git -C $r push --quiet fork "HEAD:refs/heads/$branch" 2> $null
            if ($LASTEXITCODE -eq 0) { $pushed = $true; break }
            Start-Sleep -Seconds 5
        }
        if (-not $pushed) { throw "Could not upload to your fork ($fork). Please try again in a minute." }

        $body = "Files submitted by @$me using upload.ps1."
        if ($Folder) { $body = "Files submitted by @$me using upload.ps1 (folder: $Folder)." }
        $prUrl = gh pr create --repo $Repo --base $base --head "${forkOwner}:$branch" --title $Message --body $body
        if ($LASTEXITCODE -ne 0) { throw "Your files were uploaded to your fork, but the pull request could not be created. Open https://github.com/$fork and click Contribute -> Open pull request." }

        Write-Host ""
        Write-Host "Done. Your files were submitted for review: $prUrl" -ForegroundColor Green
        Write-Host "They'll appear in the repository once the owner approves them."
    }
}
catch {
    Write-Host "Error: $($_.Exception.Message)" -ForegroundColor Red
    $exitCode = 1
}
finally {
    if ($work -and (Test-Path -LiteralPath $work)) {
        Remove-Item -LiteralPath $work -Recurse -Force -ErrorAction SilentlyContinue
    }
}
exit $exitCode
