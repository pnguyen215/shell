# Function visibility audit

Tracks functions that do not yet follow the public/private rule in [CONVENTIONS.md §2](CONVENTIONS.md#visibility-public-vs-private).

## The rule

- `shell::<category>::<name>` — public, exported, shdoc **without** `@internal`.
- `_shell::<category>::<name>` — private, **not** exported, shdoc **with** `# @internal`.

## Findings

**Status: all 152 violations renamed.** `make lint` now enforces the rule (`visibility` check). Audited `src/**/*.sh` (692 functions):

| Status                                                        | Count |
| ------------------------------------------------------------- | ----: |
| Public (`shell::*`), no `@internal` — compliant               |   540 |
| Private (`_shell::*`) with `@internal` — compliant            |   152 |
| Tagged `@internal` but still named `shell::*` — **violation** |     0 |

All 692 functions already have shdoc. No `export -f` was found under `src/`, so the exported/not-exported split is not enforced yet either.

## How to fix a function

1. Rename `shell::x::y` → `_shell::x::y` (definition, every caller, tests, docs, and help text).
2. Keep the shdoc block and the `# @internal` line.
3. Make sure it is not exported.
4. Tick it off below.

Helpers called from other files may need a public wrapper instead of a rename; decide per case (see CONVENTIONS.md §2).

## Renamed (done)

### `src/bot/telegram.sh`

- [x] `shell::telegram::mask` → `_shell::telegram::mask`
- [x] `shell::telegram::call` → `_shell::telegram::call`

### `src/core/ask.sh`

- [x] `shell::ask::read_line` → `_shell::ask::read_line`

### `src/core/clipboard.sh`

- [x] `shell::clipboard::tool` → `_shell::clipboard::tool`

### `src/core/logger_style.sh`

- [x] `shell::logger::style::valid` → `_shell::logger::style::valid`
- [x] `shell::logger::style::simple` → `_shell::logger::style::simple`
- [x] `shell::logger::style::classic` → `_shell::logger::style::classic`
- [x] `shell::logger::style::render` → `_shell::logger::style::render`
- [x] `shell::logger::style::read` → `_shell::logger::style::read`
- [x] `shell::logger::style::save` → `_shell::logger::style::save`
- [x] `shell::logger::style::save_hint` → `_shell::logger::style::save_hint`
- [x] `shell::logger::style::load` → `_shell::logger::style::load`

### `src/core/logger.sh`

- [x] `shell::logger::fmt` → `_shell::logger::fmt`

### `src/dependency/ensure.sh`

- [x] `shell::dependency::package_name` → `_shell::dependency::package_name`

### `src/dependency/homebrew.sh`

- [x] `shell::homebrew::path` → `_shell::homebrew::path`

### `src/dependency/package.sh`

- [x] `shell::package::sudo_prefix` → `_shell::package::sudo_prefix`

### `src/lang/git_history.sh`

- [x] `shell::git::history::context` → `_shell::git::history::context`
- [x] `shell::git::history::scope` → `_shell::git::history::scope`
- [x] `shell::git::history::function::resolve` → `_shell::git::history::function::resolve`
- [x] `shell::git::history::log::args` → `_shell::git::history::log::args`
- [x] `shell::git::history::log::whole` → `_shell::git::history::log::whole`
- [x] `shell::git::history::width` → `_shell::git::history::width`
- [x] `shell::git::history::fit` → `_shell::git::history::fit`
- [x] `shell::git::history::dashboard::row` → `_shell::git::history::dashboard::row`
- [x] `shell::git::history::highlighter` → `_shell::git::history::highlighter`
- [x] `shell::git::history::page` → `_shell::git::history::page`
- [x] `shell::git::history::show` → `_shell::git::history::show`
- [x] `shell::git::history::preview::command` → `_shell::git::history::preview::command`
- [x] `shell::git::history::function::candidates` → `_shell::git::history::function::candidates`

### `src/lang/git.sh`

- [x] `shell::git::branch::all::stash::lines` → `_shell::git::branch::all::stash::lines`
- [x] `shell::git::commit::spec::quote` → `_shell::git::commit::spec::quote`
- [x] `shell::git::commit::message::scan` → `_shell::git::commit::message::scan`
- [x] `shell::git::commit::message::catalog` → `_shell::git::commit::message::catalog`
- [x] `shell::git::commit::input` → `_shell::git::commit::input`
- [x] `shell::git::commit::types` → `_shell::git::commit::types`
- [x] `shell::git::commit::scope::applies` → `_shell::git::commit::scope::applies`
- [x] `shell::git::commit::scope::pick` → `_shell::git::commit::scope::pick`
- [x] `shell::git::commit::compose` → `_shell::git::commit::compose`
- [x] `shell::git::commit::body::read` → `_shell::git::commit::body::read`
- [x] `shell::git::commit::footer::token` → `_shell::git::commit::footer::token`
- [x] `shell::git::commit::footer::read` → `_shell::git::commit::footer::read`
- [x] `shell::git::commit::emoji` → `_shell::git::commit::emoji`
- [x] `shell::git::commit::emoji::enabled` → `_shell::git::commit::emoji::enabled`
- [x] `shell::git::commit::type::resolve` → `_shell::git::commit::type::resolve`
- [x] `shell::git::commit::publish` → `_shell::git::commit::publish`
- [x] `shell::git::commit::predict::issue` → `_shell::git::commit::predict::issue`
- [x] `shell::git::commit::predict::format` → `_shell::git::commit::predict::format`
- [x] `shell::git::commit::predict::evidence` → `_shell::git::commit::predict::evidence`
- [x] `shell::git::open::encode_path` → `_shell::git::open::encode_path`
- [x] `shell::git::open::web_base` → `_shell::git::open::web_base`
- [x] `shell::git::open::provider` → `_shell::git::open::provider`
- [x] `shell::git::open::url` → `_shell::git::open::url`
- [x] `shell::git::open::remote` → `_shell::git::open::remote`
- [x] `shell::git::commit::squash::preflight` → `_shell::git::commit::squash::preflight`
- [x] `shell::git::commit::squash::message` → `_shell::git::commit::squash::message`
- [x] `shell::git::commit::squash::restore` → `_shell::git::commit::squash::restore`
- [x] `shell::git::commit::amend::push_target` → `_shell::git::commit::amend::push_target`
- [x] `shell::git::config::validate` → `_shell::git::config::validate`
- [x] `shell::git::config::preflight` → `_shell::git::config::preflight`
- [x] `shell::git::config::count` → `_shell::git::config::count`
- [x] `shell::git::config::prompt` → `_shell::git::config::prompt`
- [x] `shell::git::commit::pick::in_progress` → `_shell::git::commit::pick::in_progress`
- [x] `shell::git::commit::pick::guard` → `_shell::git::commit::pick::guard`
- [x] `shell::git::commit::pick::plan` → `_shell::git::commit::pick::plan`
- [x] `shell::git::commit::pick::conflict_files` → `_shell::git::commit::pick::conflict_files`
- [x] `shell::git::commit::pick::todo` → `_shell::git::commit::pick::todo`
- [x] `shell::git::commit::pick::head_hash` → `_shell::git::commit::pick::head_hash`
- [x] `shell::git::commit::pick::control` → `_shell::git::commit::pick::control`
- [x] `shell::git::commit::pick::branches` → `_shell::git::commit::pick::branches`
- [x] `shell::git::commit::pick::fzf::candidates` → `_shell::git::commit::pick::fzf::candidates`
- [x] `shell::git::commit::pick::fzf::choose` → `_shell::git::commit::pick::fzf::choose`
- [x] `shell::git::commit::pick::fzf::engine` → `_shell::git::commit::pick::fzf::engine`
- [x] `shell::git::commit::pick::fzf::parse` → `_shell::git::commit::pick::fzf::parse`
- [x] `shell::git::diff::target` → `_shell::git::diff::target`

### `src/lang/nvm_fzf.sh`

- [x] `shell::nvm::fzf::pick` → `_shell::nvm::fzf::pick`
- [x] `shell::nvm::fzf::confirm` → `_shell::nvm::fzf::confirm`
- [x] `shell::nvm::fzf::preview` → `_shell::nvm::fzf::preview`
- [x] `shell::nvm::versions::installed` → `_shell::nvm::versions::installed`
- [x] `shell::nvm::versions::remote` → `_shell::nvm::versions::remote`
- [x] `shell::nvm::fzf::rows::installed` → `_shell::nvm::fzf::rows::installed`
- [x] `shell::nvm::aliases::user` → `_shell::nvm::aliases::user`
- [x] `shell::nvm::size::format` → `_shell::nvm::size::format`
- [x] `shell::nvm::fzf::missing` → `_shell::nvm::fzf::missing`
- [x] `shell::nvm::fzf::with_version` → `_shell::nvm::fzf::with_version`
- [x] `shell::nvm::unused::scan` → `_shell::nvm::unused::scan`

### `src/lang/nvm.sh`

- [x] `shell::nvm::version::valid` → `_shell::nvm::version::valid`
- [x] `shell::nvm::alias::valid` → `_shell::nvm::alias::valid`
- [x] `shell::nvm::invoke` → `_shell::nvm::invoke`
- [x] `shell::nvm::query` → `_shell::nvm::query`
- [x] `shell::nvm::cmd` → `_shell::nvm::cmd`
- [x] `shell::nvm::has_target` → `_shell::nvm::has_target`
- [x] `shell::nvm::autouse::hook` → `_shell::nvm::autouse::hook`

### `src/lib/brew_fzf.sh`

- [x] `shell::brew::fzf::pick` → `_shell::brew::fzf::pick`
- [x] `shell::brew::fzf::preview` → `_shell::brew::fzf::preview`
- [x] `shell::brew::fzf::confirm` → `_shell::brew::fzf::confirm`
- [x] `shell::brew::fzf::rows::installed` → `_shell::brew::fzf::rows::installed`
- [x] `shell::brew::size::format` → `_shell::brew::size::format`
- [x] `shell::brew::pin::apply` → `_shell::brew::pin::apply`
- [x] `shell::brew::unused::scan` → `_shell::brew::unused::scan`

### `src/lib/brew.sh`

- [x] `shell::brew::name::valid` → `_shell::brew::name::valid`
- [x] `shell::brew::tap::valid` → `_shell::brew::tap::valid`
- [x] `shell::brew::query` → `_shell::brew::query`
- [x] `shell::brew::pkgcmd` → `_shell::brew::pkgcmd`
- [x] `shell::brew::bundle::run` → `_shell::brew::bundle::run`

### `src/lib/net.sh`

- [x] `shell::net::port::pids` → `_shell::net::port::pids`
- [x] `shell::net::port::valid` → `_shell::net::port::valid`

### `src/lib/permission.sh`

- [x] `shell::permission::describe` → `_shell::permission::describe`

### `src/lib/rsync.sh`

- [x] `shell::rsync::spec::kind` → `_shell::rsync::spec::kind`
- [x] `shell::rsync::spec::valid` → `_shell::rsync::spec::valid`
- [x] `shell::rsync::rate::valid` → `_shell::rsync::rate::valid`
- [x] `shell::rsync::chmod::valid` → `_shell::rsync::chmod::valid`
- [x] `shell::rsync::cmd::supports` → `_shell::rsync::cmd::supports`
- [x] `shell::rsync::cmd::allow` → `_shell::rsync::cmd::allow`
- [x] `shell::rsync::cmd::only` → `_shell::rsync::cmd::only`
- [x] `shell::rsync::cmd::help` → `_shell::rsync::cmd::help`
- [x] `shell::rsync::hint` → `_shell::rsync::hint`
- [x] `shell::rsync::cmd` → `_shell::rsync::cmd`

### `src/lib/ssh_agent.sh`

- [x] `shell::ssh::agent::reachable` → `_shell::ssh::agent::reachable`

### `src/lib/ssh_cmd.sh`

- [x] `shell::ssh::target::valid` → `_shell::ssh::target::valid`
- [x] `shell::ssh::jump::valid` → `_shell::ssh::jump::valid`
- [x] `shell::ssh::option::valid` → `_shell::ssh::option::valid`
- [x] `shell::ssh::forward::valid` → `_shell::ssh::forward::valid`
- [x] `shell::ssh::spec::valid` → `_shell::ssh::spec::valid`
- [x] `shell::ssh::path::local` → `_shell::ssh::path::local`
- [x] `shell::ssh::quote` → `_shell::ssh::quote`
- [x] `shell::ssh::invoke` → `_shell::ssh::invoke`
- [x] `shell::ssh::cmd::need` → `_shell::ssh::cmd::need`
- [x] `shell::ssh::cmd::number` → `_shell::ssh::cmd::number`
- [x] `shell::ssh::cmd::supports` → `_shell::ssh::cmd::supports`
- [x] `shell::ssh::cmd::allow` → `_shell::ssh::cmd::allow`
- [x] `shell::ssh::cmd::help` → `_shell::ssh::cmd::help`
- [x] `shell::ssh::cmd` → `_shell::ssh::cmd`

### `src/lib/ssh_config.sh`

- [x] `shell::ssh::config::alias::valid` → `_shell::ssh::config::alias::valid`
- [x] `shell::ssh::config::value` → `_shell::ssh::config::value`
- [x] `shell::ssh::config::aliases` → `_shell::ssh::config::aliases`
- [x] `shell::ssh::config::backup` → `_shell::ssh::config::backup`
- [x] `shell::ssh::config::block::remove` → `_shell::ssh::config::block::remove`
- [x] `shell::ssh::config::block::insert` → `_shell::ssh::config::block::insert`
- [x] `shell::ssh::config::apply` → `_shell::ssh::config::apply`
- [x] `shell::ssh::config::table` → `_shell::ssh::config::table`
- [x] `shell::ssh::config::pick` → `_shell::ssh::config::pick`

### `src/lib/ssh_key.sh`

- [x] `shell::ssh::key::candidates` → `_shell::ssh::key::candidates`
- [x] `shell::ssh::permission::set` → `_shell::ssh::permission::set`

### `src/lib/ssh_known_hosts.sh`

- [x] `shell::ssh::known_hosts::host::valid` → `_shell::ssh::known_hosts::host::valid`
- [x] `shell::ssh::known_hosts::name` → `_shell::ssh::known_hosts::name`

### `src/skill/query.sh`

- [x] `shell::skill::manifest::file` → `_shell::skill::manifest::file`
- [x] `shell::skill::print::rows` → `_shell::skill::print::rows`

### `src/skill/runner.sh`

- [x] `shell::skill::validate::choice` → `_shell::skill::validate::choice`
- [x] `shell::skill::validate::slugs` → `_shell::skill::validate::slugs`
- [x] `shell::skill::validate::ref` → `_shell::skill::validate::ref`
- [x] `shell::skill::help::options` → `_shell::skill::help::options`
- [x] `shell::skill::run` → `_shell::skill::run`
