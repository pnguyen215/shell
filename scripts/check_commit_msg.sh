#!/usr/bin/env bash
# Conventional Commits gate for this repository: the code behind `make hooks`
# (commit-msg hook) and the CI `commit-messages` job.
#
# Rules (docs/development/commit-messages.md):
#   - the subject is `type(scope)!: description` with a conventional type and,
#     when present, a lower-case scope
#   - the whole subject is at most 72 characters (the length git recommends)
#   - the description is not empty, has no leading/trailing space, no final
#     period, and is not in the past tense (imperative mood)
#   - `Merge ...`, `Revert "..."` and `fixup!`/`squash!` messages (written by
#     git itself) are always accepted
#   - a missing issue reference (`#123`) is reported as a hint, never a failure
#
# Usage:
#   scripts/check_commit_msg.sh --file .git/COMMIT_EDITMSG   # what the hook runs
#   scripts/check_commit_msg.sh --subject 'feat(git): add thing #1'
#   scripts/check_commit_msg.sh --range master..HEAD         # every commit in a range
#
# Exit codes: 0 valid, 1 invalid, 2 usage error (also when the range is unknown).
set -u

# Conventional Commits 1.0.0 types, the same set as the template catalog (src/data).
types='build|chore|ci|docs|feat|fix|perf|refactor|revert|style|test'
# Verbs that only ever start a description written in the past tense.
past='added|changed|cleaned|configured|created|deleted|deprecated|documented|fixed|improved|implemented|introduced|migrated|moved|refactored|removed|renamed|replaced|restructured|switched|tested|updated|upgraded'

usage() {
	printf 'usage: scripts/check_commit_msg.sh --file <message-file>\n' >&2
	printf '       scripts/check_commit_msg.sh --subject <subject>\n' >&2
	printf '       scripts/check_commit_msg.sh --range <git-range>\n' >&2
}

# check_subject <subject>: validate one subject line, reporting the first problem
# found on stderr. Messages written by git (merge, revert, fixup, squash) pass.
check_subject() {
	local subject="$1" desc

	case "$subject" in
	"Merge "* | "Revert \""* | "fixup! "* | "squash! "*)
		return 0
		;;
	esac

	if ! printf '%s\n' "$subject" | grep -Eq "^(${types})(\([a-z0-9][a-z0-9.-]*\))?!?: .+"; then
		printf 'commit-msg: subject must be type(scope)!: description\n' >&2
		printf 'commit-msg: got "%s"\n' "$subject" >&2
		printf 'commit-msg: types: %s\n' "$(printf '%s' "$types" | tr '|' ' ')" >&2
		return 1
	fi

	if [ "${#subject}" -gt 72 ]; then
		printf 'commit-msg: subject is %d characters, the limit is 72\n' "${#subject}" >&2
		return 1
	fi

	desc="${subject#*: }"
	case "$desc" in
	"" | " "* | *" ")
		printf 'commit-msg: description is missing or has a leading/trailing space\n' >&2
		return 1
		;;
	*".")
		printf 'commit-msg: description must not end with a period\n' >&2
		return 1
		;;
	esac

	if printf '%s\n' "$desc" | grep -Eq "^(${past}) "; then
		printf 'commit-msg: description is in the past tense, use the imperative (add, not added)\n' >&2
		return 1
	fi

	return 0
}

[ $# -eq 2 ] || {
	usage
	exit 2
}
mode="$1"
value="$2"
case "$mode" in
--file | --subject | --range) ;;
*)
	usage
	exit 2
	;;
esac

failed=0
case "$mode" in
--file)
	[ -r "$value" ] || {
		printf 'commit-msg: cannot read %s\n' "$value" >&2
		exit 2
	}
	subject=""
	IFS= read -r subject <"$value"
	check_subject "$subject" || failed=1
	# SHOULD, not MUST: an issue reference is a hint so it never blocks a commit.
	if ! grep -Eq '#[0-9]+' "$value"; then
		printf 'hint: no issue reference (for example #123) in the message\n' >&2
	fi
	;;
--subject)
	check_subject "$value" || failed=1
	;;
--range)
	# --no-merges: real merge commits are written by git, their subjects are exempt.
	log="$(git log --no-merges --format='%h%x09%s' "$value" 2>/dev/null)" || {
		printf 'commit-msg: git log failed for range %s\n' "$value" >&2
		exit 2
	}
	while IFS=$'\t' read -r hash subject; do
		[ -n "$hash" ] || continue
		if ! check_subject "$subject"; then
			printf 'commit-msg: %s does not follow the rules\n' "$hash" >&2
			failed=1
		fi
	done <<<"$log"
	;;
esac

exit "$failed"
