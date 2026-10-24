#!/usr/bin/env bash
# shell::git::open::browser: remote URL parsing (scp/ssh/https, credentials, ports,
# aliases), provider detection, URL building per provider, target resolution, warnings,
# and the final open command. Nothing touches the network; openers are fakes.
. "$SHELL_TEST_ROOT/test/lib.sh"
t_setup

git config --global user.email "t@example.com"
git config --global user.name "Test"

web() { shell::git::open::web_base "$1"; }

# --- remote URL -> web base ------------------------------------------------------------
t_eq "scp-like ssh" "https://github.com/owner/repo" "$(web 'git@github.com:owner/repo.git')"
t_eq "https with .git" "https://github.com/owner/repo" "$(web 'https://github.com/owner/repo.git')"
t_eq "https without .git, trailing slash" "https://github.com/owner/repo" "$(web 'https://github.com/owner/repo/')"
t_eq "ssh:// with port dropped" "https://github.com/owner/repo" "$(web 'ssh://git@github.com:22/owner/repo.git')"
t_eq "git:// protocol" "https://github.com/o/r" "$(web 'git://github.com/o/r.git')"
t_eq "http(s) port is kept" "https://git.example.com:8443/o/r" "$(web 'https://git.example.com:8443/o/r.git')"
t_eq "plain http stays http" "http://git.example.com/o/r" "$(web 'http://git.example.com/o/r.git')"
t_eq "gitlab nested groups" "https://gitlab.com/group/sub/repo" "$(web 'git@gitlab.com:group/sub/repo.git')"
t_eq "host is lower-cased" "https://github.com/Owner/Repo" "$(web 'https://GitHub.COM/Owner/Repo.git')"
t_eq "ssh config alias github.com-work" "https://github.com/owner/repo" "$(web 'git@github.com-work:owner/repo.git')"
t_eq "scp-like with leading slash" "https://gitlab.example.com/o/r" "$(web 'git@gitlab.example.com:/o/r.git')"

out="$(web 'https://user:s3cr3t-token@github.com/owner/repo.git')"
t_eq "credentials are dropped" "https://github.com/owner/repo" "$out"
t_lacks "the token never reaches the URL" "s3cr3t" "$out"
t_eq "ssh credentials with @ in the password" "https://github.com/o/r" "$(web 'https://u:p@ss@github.com/o/r.git')"

t_eq "path is percent-encoded (& and spaces)" "https://github.com/o/r%26calc" "$(web 'https://github.com/o/r&calc')"
t_eq "non-ASCII path is encoded" "https://github.com/o/caf%C3%A9" "$(web 'https://github.com/o/café.git')"

for bad in '' '/srv/git/repo.git' './repo' '../repo' 'file:///srv/repo.git' 'C:\repos\x' 'C:/repos/x' \
	'https://github.com' 'https://github.com/' 'https://exa mple.com/a/b' 'https://ex;ample.com/a/b' \
	'https://git.example.com:80a/o/r' 'ftp://github.com/o/r' 'justaword'; do
	web "$bad" >/dev/null 2>&1
	t_eq "not web-hostable: [$bad]" "1" "$?"
done

# --- provider ------------------------------------------------------------------------------
mkdir "$HOME/p" && git -C "$HOME/p" init -q && cd "$HOME/p" || exit 1
prov() { shell::git::open::provider "$1"; }
t_eq "github.com" "github" "$(prov https://github.com/o/r)"
t_eq "GitHub Enterprise host" "github" "$(prov https://github.mycorp.com/o/r)"
t_eq "gitlab.com" "gitlab" "$(prov https://gitlab.com/o/r)"
t_eq "self-hosted gitlab" "gitlab" "$(prov https://gitlab.example.com:8443/g/r)"
t_eq "bitbucket.org" "bitbucket" "$(prov https://bitbucket.org/w/r)"
prov https://git.example.com/o/r >/dev/null 2>&1
t_eq "unknown host fails" "1" "$?"
git config shell.provider gitlab
t_eq "git config shell.provider decides for unknown hosts" "gitlab" "$(prov https://git.example.com/o/r)"
git config shell.provider nonsense
prov https://github.com/o/r >/dev/null 2>&1
t_eq "invalid shell.provider is an error" "1" "$?"
git config --unset shell.provider

# --- URL building ----------------------------------------------------------------------------
u() { shell::git::open::url "$@"; }
b="https://github.com/o/r"
t_eq "github repo" "$b" "$(u github $b repo)"
t_eq "github branch" "$b/tree/main" "$(u github $b branch main)"
t_eq "github commit" "$b/commit/abc123" "$(u github $b commit abc123)"
t_eq "gitlab branch" "https://gitlab.com/g/r/-/tree/main" "$(u gitlab https://gitlab.com/g/r branch main)"
t_eq "gitlab commit" "https://gitlab.com/g/r/-/commit/abc123" "$(u gitlab https://gitlab.com/g/r commit abc123)"
t_eq "bitbucket branch" "https://bitbucket.org/w/r/src/main" "$(u bitbucket https://bitbucket.org/w/r branch main)"
t_eq "bitbucket commit" "https://bitbucket.org/w/r/commits/abc123" "$(u bitbucket https://bitbucket.org/w/r commit abc123)"
t_eq "branch with slash keeps the slash" "$b/tree/feature/login" "$(u github $b branch feature/login)"
t_eq "branch with space and # is encoded" "$b/tree/feature/a%20b%231" "$(u github $b branch 'feature/a b#1')"
u svn $b branch x >/dev/null 2>&1
t_eq "unknown provider (branch)" "1" "$?"
t_eq "repo URL does not depend on the provider" "$b" "$(u svn $b repo)"
u github $b tag x >/dev/null 2>&1
t_eq "unknown kind" "1" "$?"

# --- the command, in real repositories ---------------------------------------------------------
mkrepo() {
	cd "$HOME" && rm -rf "$HOME/r" && mkdir "$HOME/r" && cd "$HOME/r" || exit 1
	git init -q && git checkout -q -b main
	git commit -q --allow-empty -m one
	git commit -q --allow-empty -m two
}
print_url() { shell::git::open::browser --print "$@" 2>/dev/null; }

mkrepo
git remote add origin git@github.com:owner/repo.git
t_eq "default target is the repo" "https://github.com/owner/repo" "$(print_url)"
t_eq "explicit repo" "https://github.com/owner/repo" "$(print_url repo)"
t_eq "branch (current)" "https://github.com/owner/repo/tree/main" "$(print_url branch)"
full="$(git rev-parse HEAD)"
t_eq "commit: HEAD resolves to the full hash" "https://github.com/owner/repo/commit/$full" "$(print_url HEAD)"
t_eq "commit: HEAD~1 resolves to the parent" "https://github.com/owner/repo/commit/$(git rev-parse HEAD~1)" "$(print_url 'HEAD~1')"
t_eq "commit: a short hash is expanded" "https://github.com/owner/repo/commit/$full" "$(print_url "$(git rev-parse --short HEAD)")"
git tag v1.0 HEAD~1
t_eq "commit: a tag works" "https://github.com/owner/repo/commit/$(git rev-parse HEAD~1)" "$(print_url v1.0)"

# upstream branch name differs from the local one
git checkout -q -b topic
git config branch.topic.remote origin
git config branch.topic.merge refs/heads/topic-remote
git update-ref refs/remotes/origin/topic-remote HEAD
t_eq "branch: the upstream name is used when it differs" "https://github.com/owner/repo/tree/topic-remote" "$(print_url branch)"
git checkout -q main

# warnings: not pushed yet
out="$(shell::git::open::browser --print branch 2>&1 >/dev/null)"
t_has "warns when the branch is not on the remote" "not on remote 'origin' yet" "$out"
git update-ref refs/remotes/origin/main HEAD
out="$(shell::git::open::browser --print branch 2>&1 >/dev/null)"
t_eq "no warning once it is there" "" "$out"
out="$(shell::git::open::browser --print HEAD 2>&1 >/dev/null)"
t_eq "no commit warning when the remote has it" "" "$out"
git commit -q --allow-empty -m three
out="$(shell::git::open::browser --print HEAD 2>&1 >/dev/null)"
t_has "warns when the commit is not on the remote" "not on remote 'origin' yet" "$out"
t_eq "...but still prints the URL" "https://github.com/owner/repo/commit/$(git rev-parse HEAD)" "$(print_url HEAD)"

# errors
shell::git::open::browser --print nonexistent-ref >/dev/null 2>&1
t_eq "invalid commit fails" "1" "$?"
shell::git::open::browser --print -- >/dev/null 2>&1
t_eq "option-looking target is rejected" "2" "$?"
shell::git::open::browser --print --bogus >/dev/null 2>&1
t_eq "unknown option is invalid usage" "2" "$?"
shell::git::open::browser --print repo branch >/dev/null 2>&1
t_eq "two targets are invalid usage" "2" "$?"
shell::git::open::browser --print -r >/dev/null 2>&1
t_eq "-r needs a value" "2" "$?"
shell::git::open::browser --print -r --evil >/dev/null 2>&1
t_eq "a remote that looks like an option is rejected" "2" "$?"
shell::git::open::browser --print -r nope >/dev/null 2>&1
t_eq "unknown remote fails" "1" "$?"
git checkout -q --detach
shell::git::open::browser --print branch >/dev/null 2>&1
t_eq "detached HEAD + branch fails" "1" "$?"
t_eq "detached HEAD + repo still works" "https://github.com/owner/repo" "$(print_url)"
git checkout -q main

# remotes
mkrepo
shell::git::open::browser --print >/dev/null 2>&1
t_eq "no remote fails" "1" "$?"
git remote add origin https://gitlab.com/group/sub/repo.git
git remote add upstream git@bitbucket.org:team/repo.git
t_eq "origin is preferred" "https://gitlab.com/group/sub/repo" "$(print_url)"
t_eq "--remote picks another provider" "https://bitbucket.org/team/repo" "$(print_url -r upstream)"
t_eq "--remote=name form" "https://bitbucket.org/team/repo" "$(print_url --remote=upstream)"
t_eq "gitlab branch URL" "https://gitlab.com/group/sub/repo/-/tree/main" "$(print_url branch)"
git remote rename origin fork >/dev/null 2>&1
shell::git::open::browser --print >/dev/null 2>&1
t_eq "several remotes and no origin fails" "1" "$?"
git config branch.main.remote upstream
t_eq "the branch's tracked remote is used for 'branch'" "https://bitbucket.org/team/repo/src/main" "$(print_url branch)"
git remote remove upstream
git remote set-url fork /srv/git/local.git
shell::git::open::browser --print >/dev/null 2>&1
t_eq "a local-path remote is rejected" "1" "$?"
git remote set-url fork "https://git.example.com/o/r.git"
shell::git::open::browser --print >/dev/null 2>&1
t_eq "unknown provider is rejected" "1" "$?"
out="$(shell::git::open::browser --print 2>&1)"
t_has "...with the fix in the message" "git config shell.provider" "$out"
git config shell.provider gitlab
t_eq "...and the config override fixes it" "https://git.example.com/o/r/-/tree/main" "$(print_url branch)"

# credentials in the remote never show up, even in dry-run output
git remote set-url fork "https://me:topsecret@github.com/owner/repo.git"
mkdir "$HOME/bin"
printf '#!/bin/sh\nprintf "%%s\\n" "$@" >"$HOME/opened.log"\n' >"$HOME/bin/xdg-open"
printf '#!/bin/sh\nprintf "%%s\\n" "$@" >"$HOME/opened.log"\n' >"$HOME/bin/open"
chmod +x "$HOME/bin/xdg-open" "$HOME/bin/open"
export PATH="$HOME/bin:$PATH"
git config --unset shell.provider
export SHELL_OS_TYPE=linux
out="$(shell::git::open::browser -n 2>&1)"
t_lacks "dry-run output has no credentials" "topsecret" "$out"
t_has "dry-run shows the opener" "xdg-open" "$out"
t_has "dry-run shows the URL" "https://github.com/owner/repo" "$out"
t_eq "dry-run opens nothing" "0" "$(test -e "$HOME/opened.log" && echo 1 || echo 0)"

# --- opening ---------------------------------------------------------------------------------
git remote set-url fork git@github.com:owner/repo.git
shell::git::open::browser >/dev/null 2>&1
t_eq "Linux: opener succeeded" "0" "$?"
t_eq "Linux: xdg-open got the URL as one argument" "https://github.com/owner/repo" "$(cat "$HOME/opened.log")"
rm -f "$HOME/opened.log"
SHELL_OS_TYPE=macos shell::git::open::browser branch >/dev/null 2>&1
t_eq "macOS: open got the branch URL" "https://github.com/owner/repo/tree/main" "$(cat "$HOME/opened.log")"
SHELL_OS_TYPE=windows shell::git::open::browser >/dev/null 2>&1
t_eq "unsupported OS is reported" "4" "$?"
t_eq "--print never opens anything" "https://github.com/owner/repo" "$(
	rm -f "$HOME/opened.log"
	shell::git::open::browser -p 2>/dev/null
)"
t_eq "...(no opener call)" "0" "$(test -e "$HOME/opened.log" && echo 1 || echo 0)"

# --- guards ----------------------------------------------------------------------------------
(cd "$HOME" && shell::git::open::browser --print >/dev/null 2>&1)
t_eq "outside a repository fails" "1" "$?"
t_rc "help" 0 shell::git::open::browser -h
t_has "help shows usage" "shell::git::open::browser" "$T_OUT"

t_done
