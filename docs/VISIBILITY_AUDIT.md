# Function visibility audit

Tracks functions that do not yet follow the public/private rule in [CONVENTIONS.md §2](CONVENTIONS.md#visibility-public-vs-private).

## The rule

- `shell::<category>::<name>` — public, exported, shdoc **without** `@internal`.
- `_shell::<category>::<name>` — private, **not** exported, shdoc **with** `# @internal`.

## Findings

Audited `src/**/*.sh` (692 functions):

| Status                                                        | Count |
| ------------------------------------------------------------- | ----: |
| Public, no `@internal` — compliant                            |   540 |
| Tagged `@internal` but still named `shell::*` — **violation** |   152 |
| Named `_shell::*` — compliant                                 |     0 |

All 692 functions already have shdoc. No `export -f` was found under `src/`, so the exported/not-exported split is not enforced yet either.

## How to fix a function

1. Rename `shell::x::y` → `_shell::x::y` (definition, every caller, tests, docs, and help text).
2. Keep the shdoc block and the `# @internal` line.
3. Make sure it is not exported.
4. Tick it off below.

Helpers called from other files may need a public wrapper instead of a rename; decide per case (see CONVENTIONS.md §2).

## Violations to rename


### `src/bot/telegram.sh`

- [ ] `shell::telegram::mask` → `_shell::telegram::mask`
- [ ] `shell::telegram::call` → `_shell::telegram::call`

### `src/core/ask.sh`

- [ ] `shell::ask::read_line` → `_shell::ask::read_line`

### `src/core/clipboard.sh`

- [ ] `shell::clipboard::tool` → `_shell::clipboard::tool`

### `src/core/logger_style.sh`

- [ ] `shell::logger::style::valid` → `_shell::logger::style::valid`
- [ ] `shell::logger::style::simple` → `_shell::logger::style::simple`
- [ ] `shell::logger::style::classic` → `_shell::logger::style::classic`
- [ ] `shell::logger::style::render` → `_shell::logger::style::render`
- [ ] `shell::logger::style::read` → `_shell::logger::style::read`
- [ ] `shell::logger::style::save` → `_shell::logger::style::save`
- [ ] `shell::logger::style::save_hint` → `_shell::logger::style::save_hint`
- [ ] `shell::logger::style::load` → `_shell::logger::style::load`

### `src/core/logger.sh`

- [ ] `shell::logger::fmt` → `_shell::logger::fmt`

### `src/dependency/ensure.sh`

- [ ] `shell::dependency::package_name` → `_shell::dependency::package_name`

### `src/dependency/homebrew.sh`

- [ ] `shell::homebrew::path` → `_shell::homebrew::path`

### `src/dependency/package.sh`

- [ ] `shell::package::sudo_prefix` → `_shell::package::sudo_prefix`

### `src/lang/git_history.sh`

- [ ] `shell::git::history::context` → `_shell::git::history::context`
- [ ] `shell::git::history::scope` → `_shell::git::history::scope`
- [ ] `shell::git::history::function::resolve` → `_shell::git::history::function::resolve`
- [ ] `shell::git::history::log::args` → `_shell::git::history::log::args`
- [ ] `shell::git::history::log::whole` → `_shell::git::history::log::whole`
- [ ] `shell::git::history::width` → `_shell::git::history::width`
- [ ] `shell::git::history::fit` → `_shell::git::history::fit`
- [ ] `shell::git::history::dashboard::row` → `_shell::git::history::dashboard::row`
- [ ] `shell::git::history::highlighter` → `_shell::git::history::highlighter`
- [ ] `shell::git::history::page` → `_shell::git::history::page`
- [ ] `shell::git::history::show` → `_shell::git::history::show`
- [ ] `shell::git::history::preview::command` → `_shell::git::history::preview::command`
- [ ] `shell::git::history::function::candidates` → `_shell::git::history::function::candidates`

### `src/lang/git.sh`

- [ ] `shell::git::branch::all::stash::lines` → `_shell::git::branch::all::stash::lines`
- [ ] `shell::git::commit::spec::quote` → `_shell::git::commit::spec::quote`
- [ ] `shell::git::commit::message::scan` → `_shell::git::commit::message::scan`
- [ ] `shell::git::commit::message::catalog` → `_shell::git::commit::message::catalog`
- [ ] `shell::git::commit::input` → `_shell::git::commit::input`
- [ ] `shell::git::commit::types` → `_shell::git::commit::types`
- [ ] `shell::git::commit::scope::applies` → `_shell::git::commit::scope::applies`
- [ ] `shell::git::commit::scope::pick` → `_shell::git::commit::scope::pick`
- [ ] `shell::git::commit::compose` → `_shell::git::commit::compose`
- [ ] `shell::git::commit::body::read` → `_shell::git::commit::body::read`
- [ ] `shell::git::commit::footer::token` → `_shell::git::commit::footer::token`
- [ ] `shell::git::commit::footer::read` → `_shell::git::commit::footer::read`
- [ ] `shell::git::commit::emoji` → `_shell::git::commit::emoji`
- [ ] `shell::git::commit::emoji::enabled` → `_shell::git::commit::emoji::enabled`
- [ ] `shell::git::commit::type::resolve` → `_shell::git::commit::type::resolve`
- [ ] `shell::git::commit::publish` → `_shell::git::commit::publish`
- [ ] `shell::git::commit::predict::issue` → `_shell::git::commit::predict::issue`
- [ ] `shell::git::commit::predict::format` → `_shell::git::commit::predict::format`
- [ ] `shell::git::commit::predict::evidence` → `_shell::git::commit::predict::evidence`
- [ ] `shell::git::open::encode_path` → `_shell::git::open::encode_path`
- [ ] `shell::git::open::web_base` → `_shell::git::open::web_base`
- [ ] `shell::git::open::provider` → `_shell::git::open::provider`
- [ ] `shell::git::open::url` → `_shell::git::open::url`
- [ ] `shell::git::open::remote` → `_shell::git::open::remote`
- [ ] `shell::git::commit::squash::preflight` → `_shell::git::commit::squash::preflight`
- [ ] `shell::git::commit::squash::message` → `_shell::git::commit::squash::message`
- [ ] `shell::git::commit::squash::restore` → `_shell::git::commit::squash::restore`
- [ ] `shell::git::commit::amend::push_target` → `_shell::git::commit::amend::push_target`
- [ ] `shell::git::config::validate` → `_shell::git::config::validate`
- [ ] `shell::git::config::preflight` → `_shell::git::config::preflight`
- [ ] `shell::git::config::count` → `_shell::git::config::count`
- [ ] `shell::git::config::prompt` → `_shell::git::config::prompt`
- [ ] `shell::git::commit::pick::in_progress` → `_shell::git::commit::pick::in_progress`
- [ ] `shell::git::commit::pick::guard` → `_shell::git::commit::pick::guard`
- [ ] `shell::git::commit::pick::plan` → `_shell::git::commit::pick::plan`
- [ ] `shell::git::commit::pick::conflict_files` → `_shell::git::commit::pick::conflict_files`
- [ ] `shell::git::commit::pick::todo` → `_shell::git::commit::pick::todo`
- [ ] `shell::git::commit::pick::head_hash` → `_shell::git::commit::pick::head_hash`
- [ ] `shell::git::commit::pick::control` → `_shell::git::commit::pick::control`
- [ ] `shell::git::commit::pick::branches` → `_shell::git::commit::pick::branches`
- [ ] `shell::git::commit::pick::fzf::candidates` → `_shell::git::commit::pick::fzf::candidates`
- [ ] `shell::git::commit::pick::fzf::choose` → `_shell::git::commit::pick::fzf::choose`
- [ ] `shell::git::commit::pick::fzf::engine` → `_shell::git::commit::pick::fzf::engine`
- [ ] `shell::git::commit::pick::fzf::parse` → `_shell::git::commit::pick::fzf::parse`
- [ ] `shell::git::diff::target` → `_shell::git::diff::target`

### `src/lang/nvm_fzf.sh`

- [ ] `shell::nvm::fzf::pick` → `_shell::nvm::fzf::pick`
- [ ] `shell::nvm::fzf::confirm` → `_shell::nvm::fzf::confirm`
- [ ] `shell::nvm::fzf::preview` → `_shell::nvm::fzf::preview`
- [ ] `shell::nvm::versions::installed` → `_shell::nvm::versions::installed`
- [ ] `shell::nvm::versions::remote` → `_shell::nvm::versions::remote`
- [ ] `shell::nvm::fzf::rows::installed` → `_shell::nvm::fzf::rows::installed`
- [ ] `shell::nvm::aliases::user` → `_shell::nvm::aliases::user`
- [ ] `shell::nvm::size::format` → `_shell::nvm::size::format`
- [ ] `shell::nvm::fzf::missing` → `_shell::nvm::fzf::missing`
- [ ] `shell::nvm::fzf::with_version` → `_shell::nvm::fzf::with_version`
- [ ] `shell::nvm::unused::scan` → `_shell::nvm::unused::scan`

### `src/lang/nvm.sh`

- [ ] `shell::nvm::version::valid` → `_shell::nvm::version::valid`
- [ ] `shell::nvm::alias::valid` → `_shell::nvm::alias::valid`
- [ ] `shell::nvm::invoke` → `_shell::nvm::invoke`
- [ ] `shell::nvm::query` → `_shell::nvm::query`
- [ ] `shell::nvm::cmd` → `_shell::nvm::cmd`
- [ ] `shell::nvm::has_target` → `_shell::nvm::has_target`
- [ ] `shell::nvm::autouse::hook` → `_shell::nvm::autouse::hook`

### `src/lib/brew_fzf.sh`

- [ ] `shell::brew::fzf::pick` → `_shell::brew::fzf::pick`
- [ ] `shell::brew::fzf::preview` → `_shell::brew::fzf::preview`
- [ ] `shell::brew::fzf::confirm` → `_shell::brew::fzf::confirm`
- [ ] `shell::brew::fzf::rows::installed` → `_shell::brew::fzf::rows::installed`
- [ ] `shell::brew::size::format` → `_shell::brew::size::format`
- [ ] `shell::brew::pin::apply` → `_shell::brew::pin::apply`
- [ ] `shell::brew::unused::scan` → `_shell::brew::unused::scan`

### `src/lib/brew.sh`

- [ ] `shell::brew::name::valid` → `_shell::brew::name::valid`
- [ ] `shell::brew::tap::valid` → `_shell::brew::tap::valid`
- [ ] `shell::brew::query` → `_shell::brew::query`
- [ ] `shell::brew::pkgcmd` → `_shell::brew::pkgcmd`
- [ ] `shell::brew::bundle::run` → `_shell::brew::bundle::run`

### `src/lib/net.sh`

- [ ] `shell::net::port::pids` → `_shell::net::port::pids`
- [ ] `shell::net::port::valid` → `_shell::net::port::valid`

### `src/lib/permission.sh`

- [ ] `shell::permission::describe` → `_shell::permission::describe`

### `src/lib/rsync.sh`

- [ ] `shell::rsync::spec::kind` → `_shell::rsync::spec::kind`
- [ ] `shell::rsync::spec::valid` → `_shell::rsync::spec::valid`
- [ ] `shell::rsync::rate::valid` → `_shell::rsync::rate::valid`
- [ ] `shell::rsync::chmod::valid` → `_shell::rsync::chmod::valid`
- [ ] `shell::rsync::cmd::supports` → `_shell::rsync::cmd::supports`
- [ ] `shell::rsync::cmd::allow` → `_shell::rsync::cmd::allow`
- [ ] `shell::rsync::cmd::only` → `_shell::rsync::cmd::only`
- [ ] `shell::rsync::cmd::help` → `_shell::rsync::cmd::help`
- [ ] `shell::rsync::hint` → `_shell::rsync::hint`
- [ ] `shell::rsync::cmd` → `_shell::rsync::cmd`

### `src/lib/ssh_agent.sh`

- [ ] `shell::ssh::agent::reachable` → `_shell::ssh::agent::reachable`

### `src/lib/ssh_cmd.sh`

- [ ] `shell::ssh::target::valid` → `_shell::ssh::target::valid`
- [ ] `shell::ssh::jump::valid` → `_shell::ssh::jump::valid`
- [ ] `shell::ssh::option::valid` → `_shell::ssh::option::valid`
- [ ] `shell::ssh::forward::valid` → `_shell::ssh::forward::valid`
- [ ] `shell::ssh::spec::valid` → `_shell::ssh::spec::valid`
- [ ] `shell::ssh::path::local` → `_shell::ssh::path::local`
- [ ] `shell::ssh::quote` → `_shell::ssh::quote`
- [ ] `shell::ssh::invoke` → `_shell::ssh::invoke`
- [ ] `shell::ssh::cmd::need` → `_shell::ssh::cmd::need`
- [ ] `shell::ssh::cmd::number` → `_shell::ssh::cmd::number`
- [ ] `shell::ssh::cmd::supports` → `_shell::ssh::cmd::supports`
- [ ] `shell::ssh::cmd::allow` → `_shell::ssh::cmd::allow`
- [ ] `shell::ssh::cmd::help` → `_shell::ssh::cmd::help`
- [ ] `shell::ssh::cmd` → `_shell::ssh::cmd`

### `src/lib/ssh_config.sh`

- [ ] `shell::ssh::config::alias::valid` → `_shell::ssh::config::alias::valid`
- [ ] `shell::ssh::config::value` → `_shell::ssh::config::value`
- [ ] `shell::ssh::config::aliases` → `_shell::ssh::config::aliases`
- [ ] `shell::ssh::config::backup` → `_shell::ssh::config::backup`
- [ ] `shell::ssh::config::block::remove` → `_shell::ssh::config::block::remove`
- [ ] `shell::ssh::config::block::insert` → `_shell::ssh::config::block::insert`
- [ ] `shell::ssh::config::apply` → `_shell::ssh::config::apply`
- [ ] `shell::ssh::config::table` → `_shell::ssh::config::table`
- [ ] `shell::ssh::config::pick` → `_shell::ssh::config::pick`

### `src/lib/ssh_key.sh`

- [ ] `shell::ssh::key::candidates` → `_shell::ssh::key::candidates`
- [ ] `shell::ssh::permission::set` → `_shell::ssh::permission::set`

### `src/lib/ssh_known_hosts.sh`

- [ ] `shell::ssh::known_hosts::host::valid` → `_shell::ssh::known_hosts::host::valid`
- [ ] `shell::ssh::known_hosts::name` → `_shell::ssh::known_hosts::name`

### `src/skill/query.sh`

- [ ] `shell::skill::manifest::file` → `_shell::skill::manifest::file`
- [ ] `shell::skill::print::rows` → `_shell::skill::print::rows`

### `src/skill/runner.sh`

- [ ] `shell::skill::validate::choice` → `_shell::skill::validate::choice`
- [ ] `shell::skill::validate::slugs` → `_shell::skill::validate::slugs`
- [ ] `shell::skill::validate::ref` → `_shell::skill::validate::ref`
- [ ] `shell::skill::help::options` → `_shell::skill::help::options`
- [ ] `shell::skill::run` → `_shell::skill::run`
