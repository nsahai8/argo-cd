#!/usr/bin/env bash

if [ "$1" == "" ] || [ "$2" == "" ] || [ "$3" == "" ]; then
cat <<-EOM
USAGE:

  generate-release-notes.sh NEW_REF OLD_REF NEW_VERSION

EXAMPLES:

  # For releasing a new minor version:
  generate-release-notes.sh release-2.5 release-2.4 v2.5.0-rc1 > /tmp/release.md

  # For a patch release:
  generate-release-notes.sh release-2.4 v2.4.13 v2.4.14 > /tmp/release.md
EOM
exit 1
fi

function to_list_items() {
  sed 's/^/- /'
}

function strip_last_word() {
  sed 's/ [^ ]*$//'
}

function nonempty_line_count() {
  sed '/^\s*$/d' | wc -l | tr -d ' \n'
}

function only_last_word() {
  awk 'NF>1{print $NF}'
}

new_ref=$1
old_ref=$2
version=$3

cat <<-EOM
## Quick Start

### Non-HA:

\`\`\`shell
kubectl create namespace argocd
kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/$version/manifests/install.yaml
\`\`\`

### HA:

\`\`\`shell
kubectl create namespace argocd
kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/$version/manifests/ha/install.yaml
\`\`\`

## Upgrading

If upgrading from a different minor version, be sure to read the [upgrading](https://argo-cd.readthedocs.io/en/stable/operator-manual/upgrading/overview/) documentation.

EOM

# Adapted from https://stackoverflow.com/a/67029088/684776
less_log=$(git log --pretty="format:%s %ae" --cherry-pick --left-only --no-merges "$new_ref...$old_ref")
more_log=$(git log --pretty="format:%s %ae" "$new_ref..$old_ref")

new_commits=$(diff --new-line-format="" --unchanged-line-format="" <(echo "$less_log") <(echo "$more_log") | grep -v "Merge pull request from GHSA")
new_commits_no_email=$(echo "$new_commits" | strip_last_word)

contributors_num=$(echo "$new_commits" | only_last_word | sort -u | nonempty_line_count)

new_commits_num=$(echo "$new_commits" | nonempty_line_count)
features_num=$(echo "$new_commits_no_email" | grep '^feat' | nonempty_line_count)
fixes_num=$(echo "$new_commits_no_email" | grep '^fix' | nonempty_line_count)

previous_contributors=$(git log --pretty="format:%an %ae" "$old_ref" | sort -uf)
all_contributors=$(git log --pretty="format:%an %ae" "$new_ref" | sort -uf)
new_contributors=$(diff --new-line-format="" --unchanged-line-format="" <(echo "$all_contributors") <(echo "$previous_contributors"))
new_contributors_num=$(echo "$new_contributors" | only_last_word | nonempty_line_count)  # Count contributors by email
new_contributors_names=$(echo "$new_contributors" | strip_last_word | to_list_items)

new_contributors_message=""
if [ "$new_contributors_num" -gt 0 ]; then
  new_contributors_message=" ($new_contributors_num of them new)"
fi

echo "## Changes"
echo
echo "This release includes $new_commits_num contributions from $contributors_num contributors$new_contributors_message with $features_num features and $fixes_num bug fixes."
echo
if [ "$new_contributors_num" -lt 20 ] && [ "$new_contributors_num" -gt 0 ]; then
  echo "A special thanks goes to the $new_contributors_num new contributors:"
  echo "$new_contributors_names"
  echo
fi
