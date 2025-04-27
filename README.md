# AWS CLI Browsers – S3 & CloudWatch

> **Note:** Most of the code and documentation in this project was generated with the assistance of AI tools.


Terminal utilities for browsing AWS resources with **fzf**:

* `s3browser` - S3 buckets & objects
* `cwbrowser` - CloudWatch logs

Wraps AWS CLI with local caching and fuzzy search.

---

## Prerequisites

* [AWS CLI](https://docs.aws.amazon.com/cli/) – configured with credentials
* [fzf](https://github.com/junegunn/fzf)

---

## Installation

**One-liner:**

```bash
curl -fsSL https://raw.githubusercontent.com/nocturnalAndroid/aws_cli_browsers/main/install-remote.sh | bash
```

**Or, manually:**

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

## s3browser

Usage:

```bash
$ s3browser                                # start at bucket list
$ s3browser my-bucket                      # jump straight to bucket
$ s3browser my-bucket/folder/prefix        # jump to prefix
$ s3browser s3://my-bucket/folder/prefix   # also works like this
$ s3browser my-bucket folder/prefix        # or like this
```

In the interfase navigate using the arrow keys + return key / mouse / start typing for fuzzy search

---

### Caching

* Bucket list stored in `~/.s3browser/buckets.txt`.
* Last 20 buckets in `~/.s3browser/recent_buckets.txt` are shown on top.
* Clear cache with:

```bash
$ s3browser --clear-cache
```

---

## cwbrowser – features & examples

Usage:

```bash
$ cwbrowser                                     # start at log groups list
$ cwbrowser "/aws/lambda/my-fn"                 # jump to log group
$ cwbrowser "/aws/lambda/my-fn" my-stream-name  # jump to stream
$ cwbrowser --search-stream my-stream-name      # find stream in recent groups
$ cwbrowser --clear-cache                       # clear profile cache
$ cwbrowser --clear-cache --all                 # clear cache for all profiles
```

In the interfase navigate using the arrow keys + return key / mouse / start typing for fuzzy search

### Caching

Group list cached under `~/.cwbrowser/$AWS_PROFILE/`.  
The cache refreshes in the background.
Note: Newly created log groups won't appear until the next cache refresh.
Use `--clear-cache` to reset.

---

## Uninstall

You can uninstall using any of these methods:

```bash
$ s3browser --uninstall     # run the uninstall script with confirmation
$ cwbrowser --uninstall     # same as above
$ awsclibrowser-uninstall   # direct uninstall script
```

Or manually:

```bash
rm -f ~/.local/bin/{s3browser,cwbrowser}
rm -rf ~/.s3browser ~/.cwbrowser
```

---


[License](LICENSE)
------------------

The MIT License (MIT)