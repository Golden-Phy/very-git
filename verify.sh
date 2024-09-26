
parse_file_list(){
  local -n files="$1"
  # Normalize paths with trailing slash and sort them
  sorted_dirs=()
  while IFS= read -r line; do
    sorted_dirs+=("$line")
  done < <(for file in "${files[@]}"; do
      dirname "$file" | sed 's|/*$|/|'
    done | sort -ru)
  # Traverse the sorted directories and find the shortest paths
  for (( i=0; i<${#sorted_dirs[@]}; i++ )); do
    current="${sorted_dirs[$i]}"
    next="${sorted_dirs[$i+1]:-}"
    # Include current if next does not start with current prefix
    if [[ "" == "$next" || "$current" != "$next"* ]]; then
      echo "$current"
    fi
  done
}

verify_change_authorization() {
    local -n dirs="$1"
    local -n perm_map="$2"
    local fingerprint="$3"
        echo "$fingerprint"

    faults=()
    # Iterate over each longest directory
    for dir in "${dirs[@]}"; do
        echo "Checking directory: $dir"
        # Split directory into parts using '/'
        IFS='/' read -r -a parts <<< "$dir"
        # Combine prefixes and check in perm_map
        combined_fingerprints="${perm_map["."]}"
        prefix=""
        # Construct the prefix incrementally
        for part in "${parts[@]}"; do
            prefix+="$part"
            # Check if the prefix exists in the perm_map
            if [[ -n ${perm_map["$prefix"]} ]]; then
                combined_fingerprints+="${perm_map["$prefix"]}\n"
            fi
            prefix+="/"
        done
        # Check if fingerprint exists in combined fingerprints
        if ! echo -e "$combined_fingerprints" | tr -d '\t ' | grep -iqF "$fingerprint"; then faults+=("$dir"); fi
    done
    if [ ${#faults[@]} -ne 0 ]; then
        echo "Unauthorized changes in the directories: ${faults[*]}" 1>&2
        return 1
    fi
}


test_verify_change_authorization(){
  # Define the directories
  local touched_dirs=("alpha" "alpha/beta/" "gamma/delta/" "gamma/epsilon/")

  # Define the permission map
  declare -A permission_map
  permission_map["."]="000"
  permission_map["alpha"]="009\n008"
  permission_map["alpha/beta"]="008\n007"
  permission_map["gamma"]="007\n000"
  permission_map["gamma/delta"]="009\004"
  verify_change_authorization touched_dirs permission_map "000"
  verify_change_authorization touched_dirs permission_map "007"
  echo "alpha should have been reported"
}

# Test function for verify_changes
test_parse_file_list(){
    # Define an array of file paths (example data)
    local test_files=(
        "alpha/beta/file1"
        "alpha/beta/gamma/file2"
        "gamma/delta/file3"
        "gamma/epsilon/file4"
        "gamma/epsilon/.auth"
        "alpha/.auth"
    )
    parse_file_list test_files
}
