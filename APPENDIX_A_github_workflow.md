# Appendix A — GitHub Setup & the Project Push Workflow

Every lab in the book ends with a working project pushed to GitHub. This is the exact
sequence, repeated for every chapter. Do not skip the venv. Do not skip the push.

## Part 1 — Create your GitHub account

1. Go to **github.com** → **Sign up**.
2. Choose a professional username (e.g. `jsmith-dev`) — it becomes part of every repo URL.
3. Verify your email.

## Part 2 — Install and configure Git

```bash
# macOS
xcode-select --install
# Ubuntu/Debian
sudo apt update && sudo apt install git -y
# Windows: install from https://git-scm.com/downloads

git config --global user.name  "Your Full Name"
git config --global user.email "you@example.com"
```

## Part 3 — The project push workflow (every chapter)

```bash
# PHASE 1 — folder + virtual environment
cd ~/ai-ml-engineer/chapter-XX-...           # the chapter's lab folder
python3 -m venv venv
source venv/bin/activate                  # Windows: venv\Scripts\activate
pip install -r requirements.txt           # or the chapter's pip install line

# PHASE 2 — write code, then commit
git init
echo "venv/"          >  .gitignore
echo "__pycache__/"   >> .gitignore
echo "*.pyc"          >> .gitignore
git add .
git commit -m "Chapter XX lab complete"

# PHASE 3 — create the repo on github.com (Public, no README), then:
git remote add origin https://github.com/YOUR-USERNAME/REPO-NAME.git
git branch -M main
git push -u origin main

# PHASE 4 — finish
deactivate
```

If Git asks for a password and your GitHub password fails, create a **Personal Access
Token** (Settings → Developer settings → Personal access tokens, `repo` scope) and use it
as the password.

## In this repository

This repo treats the whole `ai-ml-engineer` workspace as **one** Git repository (its root
is the workspace), so the GitHub Actions workflows in [`.github/workflows/`](.github/workflows/)
run against the `chapter-XX-*` folders directly. The root [`.gitignore`](.gitignore) already
excludes `venv/`, build artifacts, Terraform state, and secrets.

## Cross-platform command reference

| Task | macOS / Linux | Windows |
|---|---|---|
| Activate venv | `source venv/bin/activate` | `venv\Scripts\activate` |
| Python 3 | `python3 script.py` | `python script.py` |
| Install packages | `pip3 install pkg` | `pip install pkg` |
| List files | `ls -la` | `dir` |
| Set env variable | `export VAR=value` | `set VAR=value` (CMD) · `$env:VAR="value"` (PS) |
| Git / Docker / kubectl / terraform | same | same |
