# skill/runner.sh

Shared engine behind shell::skill::install / upgrade / uninstall / sync.

## Overview

The skills library (https://github.com/pnguyen215/skills) is a set of
standalone installers (`install.sh`, `upgrade.sh`, `uninstall.sh`,
`sync_claude.sh`, `sync_opencode.sh`). This module does not re-implement
them: it validates the options, downloads the matching script from
`SHELL_SKILL_REPO_SLUG` and runs it with `bash`, through
`shell::net::run_remote_script` (download first, check it is not empty,
then execute; no `curl | bash`).

The scripts never use `sudo` and only write below `$HOME` or an explicit
`--project-dir`.
