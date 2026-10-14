# file_upload

This repository collects files submitted by external contributors. You can submit any type of file: documents, images, archives, data files and more.

**Before you start:** you need a free GitHub account. Sign up at https://github.com/signup if you don't have one.

There are three ways to submit files:

- **You were invited as a collaborator** (you accepted an email invitation to this repo): follow [Option A](#option-a-direct-upload-collaborators-only).
- **You weren't invited:** follow [Option B](#option-b-submit-via-pull-request-anyone). Your files are reviewed and added by the repo owner.
- **You prefer the command line, or have files over 25 MB:** follow [Option C](#option-c-upload-script-windows-macos-linux). The script works out which of A or B applies to you.

If you aren't sure, try Option A. If you don't see an **Upload files** option, or GitHub asks you to fork the repository, use Option B.

---

## Option A: Direct upload (collaborators only)

1. Go to https://github.com/amittal2026/file_upload and sign in.
2. Open the folder you were asked to upload into, if any.
3. Click **Add file** → **Upload files**.
4. Drag your file(s) onto the page, or click **choose your files**. You can upload up to 100 files at once, each up to 25 MB.
5. In the **Commit changes** box, describe what you're uploading, e.g. `Add signed contract - Acme Ltd`.
6. Select **Commit directly to the `main` branch**.
7. Click **Commit changes**.

Your files now appear in the repository.

---

## Option B: Submit via pull request (anyone)

You'll make your own copy of the repository (a "fork"), add your files to it, and then ask the owner to bring them in (a "pull request").

### 1. Fork the repository
1. Go to https://github.com/amittal2026/file_upload and sign in.
2. Click **Fork** (top right), then **Create fork**.
3. You're now on your copy, at `github.com/<your-username>/file_upload`.

### 2. Upload your files to your fork
1. On your fork, click **Add file** → **Upload files**.
2. Drag your file(s) onto the page, or click **choose your files**. Each file can be up to 25 MB.
3. Write a short description, e.g. `Add Q3 report from Acme Ltd`.
4. Click **Commit changes**.

### 3. Send your files to the owner
1. On your fork, click **Contribute** → **Open pull request**.
2. Add a title and a short note about what you're submitting and who you are.
3. Click **Create pull request**.

That's it. The owner reviews your pull request and merges it, which adds your files to the repository. You'll get an email notification when that happens or if the owner has questions.

> **Submitting more files later?** On your fork, click **Sync fork** → **Update branch** first, then repeat steps 2 and 3.

---

## Option C: Upload script (Windows, macOS, Linux)

A script that uploads files and folders in one command. If you're a collaborator, your files go straight into the repository. Otherwise the script forks the repository and opens a pull request for you, so the owner can review it. It handles files up to 100 MB each.

### 1. Install the tools (one-time)

The script needs **Git** and the **GitHub CLI**.

| System | Install command |
|---|---|
| Windows | `winget install Git.Git GitHub.cli` (then open a new PowerShell window) |
| macOS | `brew install git gh` (needs [Homebrew](https://brew.sh)) |
| Linux | Install `git` with your package manager, and `gh` from https://cli.github.com |

The first time you run the script, it asks you to sign in to GitHub in your browser.

### 2a. Windows (PowerShell)

Download the script:

```powershell
Invoke-WebRequest https://raw.githubusercontent.com/amittal2026/file_upload/main/upload.ps1 -OutFile upload.ps1
```

Upload files or folders:

```powershell
powershell -ExecutionPolicy Bypass -File .\upload.ps1 report.pdf
powershell -ExecutionPolicy Bypass -File .\upload.ps1 -Folder acme-ltd -Message "Q3 documents" report.pdf .\scans
```

### 2b. macOS / Linux (Bash)

Download the script:

```bash
curl -fsSLO https://raw.githubusercontent.com/amittal2026/file_upload/main/upload.sh
chmod +x upload.sh
```

Upload files or folders:

```bash
./upload.sh report.pdf
./upload.sh -d acme-ltd -m "Q3 documents" report.pdf scans/
```

### Options

| PowerShell | Bash | Meaning |
|---|---|---|
| `-Folder <name>` | `-d <name>` | Folder in the repository to put the files in. Default: the top level. |
| `-Message "<text>"` | `-m "<text>"` | Short description of the upload. |

When it finishes, the script prints a link to your files, or to the pull request if the owner needs to review them.

---

## File size limits

| Size (per file) | What to do |
|---|---|
| Up to 25 MB | Upload through the website (Option A or B) or the script (Option C) |
| 25–100 MB | Use the upload script (Option C) |
| Over 100 MB | GitHub doesn't accept these. Split the file into smaller parts (e.g. a multi-part ZIP) or contact the repository owner for another way to send it |

---

## Guidelines

- Use clear, descriptive file names, e.g. `acme-ltd_report_2026-10-14.pdf`.
- Avoid spaces in file names. Use `-` or `_` instead.
- **Don't upload files containing passwords, keys or confidential personal data.** If this repository is public, anyone on the internet can see the files in it, and in pull requests.
- Questions? Open an issue at https://github.com/amittal2026/file_upload/issues.
