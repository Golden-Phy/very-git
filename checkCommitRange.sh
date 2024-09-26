#!/bin/bash
if [ "$#" -ne 4 ]; then
  echo "Usage: $0 <target commit> <starting commit> <introduction commit> <repository path>" >&2
  exit 1
fi
new_commit="$1"
current_commit="$2" #$(git --git-dir="$git_dir" rev-parse HEAD)
intro_commit="$3"
start_commit="$current_commit"
git_dir="$4"
source verify.sh
declare -A permission_map
# Extract all .auth files and build permission map
while read -r _ _ _ name; do
  # Save the .auth content in a map with directory paths
  dir=$(dirname "${name}")
  permission_map["$dir"]=$(git --git-dir="$git_dir" show "${start_commit}:${name}")
done < <(git --git-dir="$git_dir" ls-tree -r "${start_commit}" | grep '.auth')
blocking=$( diff  <(git --git-dir="$git_dir" rev-list "$new_commit" --not "$intro_commit" --ancestry-path) <(git --git-dir="$git_dir" rev-list "$new_commit" --not "$intro_commit") )
if [ "$blocking" ]; then
    echo "bad format. The following commits are not ancestors of the introduction: ${blocking[*]}" 1>&2
    exit 1
fi
if ! git --git-dir="$git_dir" merge-base --is-ancestor "$intro_commit" "$current_commit"; then
    echo "bad state. The current commit is not a descendant of the introduction at $intro_commit"  1>&2
    exit 1
fi
while read -r commit; do
  echo "Processing revision $commit"
  fingerprint_raw=$(git --git-dir="$git_dir" -c gpg.program="$(which gpg)" verify-commit --raw "$commit" 2>&1) ||
  (gpg --import keys/*/*.asc &> /dev/null &&
    fingerprint_raw=$(git --git-dir="$git_dir" -c gpg.program="$(which gpg)" verify-commit --raw "$commit" 2>&1)) ||
  (echo -e "bad signature or unknown key.\n$fingerprint_raw" 1>&2 && exit 1)
  fingerprint=$(echo "$fingerprint_raw" | awk '/VALIDSIG/{print $NF}') #get primary key fingerprint
  gpg --with-colons --list-keys "$fingerprint" | awk -F: '$1=="uid" { print $10 }'
  changed_files=$(git --git-dir="$git_dir" diff-tree --no-renames -w --no-commit-id --name-only -r "$commit")
  mapfile -t touched_dirs < <(parse_file_list changed_files)
  verify_change_authorization touched_dirs permission_map "$fingerprint" || exit 1
  auth_changes=$(echo "$changed_files" | grep ".*\.auth")
  if [  "${auth_changes[*]}" = '' ]; then continue; fi; #counting for some reason doesn't cut it
  echo "Authoristion changes: '${auth_changes[*]}'"
  while read -r auth_file; do
    dir=$(dirname "$auth_file")
    permission_map["$dir"]=$(git --git-dir="$git_dir" show "$commit:$dir/.auth")
  done < <(echo "$auth_changes")
  echo "Testing for footguns"
  verify_change_authorization touched_dirs permission_map "$fingerprint" || exit 1
done < <(git --git-dir="$git_dir" rev-list --first-parent "$new_commit" --not "$current_commit" --reverse)
