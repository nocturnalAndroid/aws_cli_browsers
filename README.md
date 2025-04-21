# AWS CLI Browsers – S3 & CloudWatch

Interactive terminal utilities powered by **fzf** for quickly browsing:

* **S3 buckets / objects** (`s3browser`)
* **CloudWatch log groups / streams** (`cwbrowser`)

Both scripts wrap the AWS CLI, cache remote listings locally, and provide easy navigation using fzf.

---

## Prerequisites

* [AWS CLI](https://docs.aws.amazon.com/cli/) – configured with credentials
* [fzf](https://github.com/junegunn/fzf)

---

## Installation

```bash
# 1. clone the repo
$ git clone https://github.com/your/repo.git
$ cd repo

# 2. run the helper script
$ ./install.sh
```

`install.sh` will:

1. Copy the scripts into `~/.local/bin` as `s3browser` and `cwbrowser`.
2. Generate shell‑completion files (bash & zsh) under `~/.s3browser/completion`.
3. Add `~/.local/bin` to your `PATH` and enable completions (you may need to restart or `source ~/.zshrc`).

---

## s3browser – features & examples

Launch without arguments:

```bash
$ s3browser           # list buckets
```

### Accepts an optional start path

```bash
$ s3browser my-bucket                       # jump straight to bucket
$ s3browser my-bucket/folder/prefix         # jump to prefix
$ s3browser s3://my-bucket/folder/prefix    # jump to prefix
$ s3browser my-bucket folder/prefix         # legacy 2‑arg form
```

### Navigation keys

* `↑ / ↓ / type` – move / fuzzy‑filter the list (powered by **fzf**)
* `Enter` – open bucket, folder, or file action menu
* `Ctrl‑C` – go back / exit

### Bucket list helpers

While the bucket list is open press **Include pattern** or **Exclude pattern** to run `grep` style filters.

### File action menu

Actions shown depend on file type (zip adds unzip options):

* Open in **VSCode / Vi / Nano / Less**
* **Cat** to stdout
* **Copy S3 path** to clipboard (`pbcopy`)
* **Download** (plain, open in editor, reveal in Finder)
* **Download & unzip**

### Caching

* Bucket list stored in `~/.s3browser/buckets.txt`.
* Last 20 buckets in `recent_buckets.txt` are shown on top.
* Clear everything with:

```bash
$ s3browser --clear-cache
```

---

## cwbrowser – features & examples

Start with no args:

```bash
$ cwbrowser       # list log groups
```

### Optional arguments

```bash
$ cwbrowser "/aws/lambda/my-fn"                 # jump to log group
$ cwbrowser "/aws/lambda/my-fn" my-stream-name  # jump to stream
$ cwbrowser --search-stream my-stream-name      # find stream in recent groups
$ cwbrowser --clear-cache            # clear profile cache
$ cwbrowser --clear-cache --all      # clear cache for all profiles
```

### Navigation & menus

1. **Select Log Group** – recent groups (top) + all groups (size shown).
2. **Select Log Stream** – streams sorted by last event time (timestamp shown).
3. **Action Menu** for a stream:
   * View logs – **Message only**, **Timestamp + Message**, **Raw JSON**
   * Download logs – JSON, text, CSV
   * Copy stream name to clipboard

### Caching

Group list cached under `~/.cwbrowser/$AWS_PROFILE/`.  The cache refreshes in the background. Use `--clear-cache` to reset.

---

## Tips & Tricks

* Both tools respect the `AWS_PROFILE` env var.
* Use the arrow keys or just start typing to fuzzy‑match anything.
* Output pipes through `less` for paging where relevant.

---

## Uninstall

```bash
rm -f ~/.local/bin/{s3browser,cwbrowser}
rm -rf ~/.s3browser ~/.cwbrowser
```

---
