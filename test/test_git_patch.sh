#!/usr/bin/env bash
# shell::git::patch::create and shell::git::patch::apply::fzf on a throwaway repo.
# fzf is faked: it prints the first candidate, or exits 130 (ESC) when FAKE_FZF_ESC=1.
. "$SHELL_TEST_ROOT/test/lib.sh"
t_setup

mkdir "$HOME/bin"
cat >"$HOME/bin/fzf" <<'FAKE'
#!/bin/sh
[ "$FAKE_FZF_ESC" = "1" ] && exit 130
head -n 1
FAKE
chmod +x "$HOME/bin/fzf"
export PATH="$HOME/bin:$PATH" FAKE_FZF_ESC=0

mkdir "$HOME/repo" && cd "$HOME/repo" || exit 1
git init -q . && git config user.email t@t && git config user.name t
printf 'one\n' >a.txt && printf 'x\n' >b.txt
git add . && git commit -q -m init

# --- create: clean tree
t_rc "create: clean tree is not an error" 0 shell::git::patch::create
t_has "create: clean tree says nothing to save" "nothing to save" "$T_OUT"

# --- create: staged + unstaged + untracked
printf 'two\n' >>a.txt
printf 'y\n' >>b.txt && git add b.txt
printf 'new\n' >"new file.txt"
t_rc "create: writes the patch" 0 shell::git::patch::create work
t_eq "create: .patch appended" "yes" "$([ -f work.patch ] && echo yes || echo no)"
p="$(cat work.patch)"
t_has "create: unstaged change" "+two" "$p"
t_has "create: staged change" "+y" "$p"
t_has "create: untracked file" "+new" "$p"
t_eq "create: index untouched (new file still untracked)" "?? \"new file.txt\"" "$(git status --porcelain | grep 'new file')"
t_rc "create: refuses to overwrite" 7 shell::git::patch::create work
t_rc "create: dry run writes nothing" 0 shell::git::patch::create -n dry
t_eq "create: dry run left no file" "no" "$([ -f dry.patch ] && echo yes || echo no)"
t_rc "create: unknown option" 2 shell::git::patch::create --bogus

# --- apply: round trip on a clean checkout
mkdir "$HOME/patches" && mv work.patch "$HOME/patches/"
git stash -u -q
P="$HOME/patches"
t_rc "apply: dry run prints command" 0 shell::git::patch::apply::fzf -n "$P"
t_has "apply: dry run shows git apply" "git apply" "$T_OUT"
t_eq "apply: dry run changed nothing" "one" "$(cat a.txt)"
t_rc "apply: applies the picked patch" 0 shell::git::patch::apply::fzf "$P"
t_eq "apply: tracked change back" "two" "$(sed -n 2p a.txt)"
t_eq "apply: untracked file back" "new" "$(cat 'new file.txt')"

# --- apply: second time conflicts, cancel and empty dir
t_rc "apply: already applied fails cleanly" 1 shell::git::patch::apply::fzf "$P"
FAKE_FZF_ESC=1
t_rc "apply: ESC is not an error" 0 shell::git::patch::apply::fzf "$P"
FAKE_FZF_ESC=0
mkdir empty
t_rc "apply: no patches is not an error" 0 shell::git::patch::apply::fzf empty
t_has "apply: no patches message" "No .patch files" "$T_OUT"
t_rc "apply: missing dir" 3 shell::git::patch::apply::fzf nowhere

t_done
