#!/bin/bash

# Function to determine if a file is binary
is_binary() {
    # Check if the file is a regular file and not empty
    if [ -f "$1" ] && [ -s "$1" ]; then
        # Use 'file' command to check file type. Grep for "binary" or "executable"
        # or common image/archive types.
        if file "$1" | grep -qE 'binary|executable|archive|image data|JPEG|PNG|GIF|PDF|data'; then
            return 0 # It's binary
        fi
    fi
    return 1 # It's not binary or doesn't exist/is empty
}

# Function to get the file extension and map it to a common code block type
get_file_extension_type() {
    local filename=$(basename "$1")
    local extension="${filename##*.}"
    case "$extension" in
        py) echo "py" ;;
        txt) echo "txt" ;;
        png|jpg|jpeg|gif|bmp|webp) echo "png" ;; # Group image types
        json) echo "json" ;;
        sh) echo "bash" ;;
        md) echo "markdown" ;;
        yml|yaml) echo "yaml" ;;
        xml) echo "xml" ;;
        html|htm) echo "html" ;;
        css) echo "css" ;;
        js) echo "js" ;;
        ts) echo "ts" ;;
        java) echo "java" ;;
        c|cpp|h) echo "c" ;;
        go) echo "go" ;;
        rb) echo "ruby" ;;
        php) echo "php" ;;
        Dockerfile) echo "Dockerfile" ;; # Specific case for Dockerfile
        *) echo "txt" ;; # Default to text for unknown types
    esac
}

# Function to find the longest common path prefix
find_common_prefix() {
    local paths_array=("$@")
    if [ ${#paths_array[@]} -eq 0 ]; then
        echo ""
        return
    fi

    local common_prefix="${paths_array[0]}"
    # If the first path is a file, start with its directory.
    # Otherwise, the path itself is the initial common prefix.
    if [ -f "$common_prefix" ]; then
        common_prefix=$(dirname "$common_prefix")
    fi

    for ((i=1; i<${#paths_array[@]}; i++)); do
        local current_path="${paths_array[i]}"
        local temp_prefix=""
        local min_len=${#common_prefix}
        if [ ${#current_path} -lt $min_len ]; then
            min_len=${#current_path}
        fi

        for ((j=0; j<min_len; j++)); do
            if [ "${common_prefix:$j:1}" == "${current_path:$j:1}" ]; then
                temp_prefix="${temp_prefix}${common_prefix:$j:1}"
            else
                break
            fi
        done
        common_prefix="$temp_prefix"
    done

    # Ensure the common prefix ends at a directory boundary
    if [[ "$common_prefix" == */ ]]; then
        common_prefix="${common_prefix%/}"
    fi

    # If the common prefix is empty, it means paths are in different roots or
    # there's no common directory. In this case, we might default to the current working directory,
    # or handle it as an error/special case. For this script, we'll try to find the deepest common
    # part that is a directory.
    while [ ! -d "$common_prefix" ] && [[ "$common_prefix" != "" ]]; do
        common_prefix=$(dirname "$common_prefix")
    done

    # If the common_prefix is just "/", strip it if it's the only character
    if [ "$common_prefix" == "/" ]; then
        echo ""
    else
        echo "$common_prefix"
    fi
}

# Function to generate the file map structure (recursive)
generate_tree() {
    local dir="$1"
    local prefix="$2"
    local excluded_items=("$3") # Array of excluded items (e.g., base directory itself)
    local is_last_dir="$4" # "true" or "false"
    local current_level_indent="$5"

    local current_indent="${current_level_indent}"
    local new_level_indent="${current_level_indent}"

    # Determine connector for this level
    local connector="├── "
    local dir_connector="└── "
    if [ "$is_last_dir" == "true" ]; then
        connector="└── "
        new_level_indent+="    "
    else
        new_level_indent+="│   "
    fi

    local items=()
    # List all files and directories in the current directory, sorted
    while IFS= read -r -d $'\0'; do
        items+=("$REPLY")
    done < <(find "$dir" -maxdepth 1 -mindepth 1 -print0 | sort -z)

    local total_items=${#items[@]}
    local item_count=0

    for item_path in "${items[@]}"; do
        local item_name=$(basename "$item_path")
        
        # Skip if item_name is in the excluded_items array
        local skip_item=false
        for excluded in "${excluded_items[@]}"; do
            if [[ "$item_name" == "$excluded" ]]; then
                skip_item=true
                break
            fi
        done
        if [ "$skip_item" == "true" ]; then
            continue
        fi

        item_count=$((item_count + 1))
        local is_last_item="false"
        if [ "$item_count" -eq "$total_items" ]; then
            is_last_item="true"
        fi

        local item_prefix="${current_indent}"
        if [ "$is_last_item" == "true" ]; then
            item_prefix+="└── "
        else
            item_prefix+="├── "
        fi

        if [ -d "$item_path" ]; then
            echo "${item_prefix}${item_name}  "
            generate_tree "$item_path" "$prefix" "${excluded_items[*]}" "$is_last_item" "$new_level_indent"
        elif [ -f "$item_path" ]; then
            echo "${item_prefix}${item_name}  "
        fi
    done
}

# Main script logic
input_file="$1"

echo "--- DEBUG INFO ---"
echo "Input file: $1"
echo "--------------------"

# Read file paths from the input file into an array
file_paths=()
while IFS= read -r line; do
    file_paths+=("$line")
done < "$1"

declare -a all_absolute_paths
for path in "${file_paths[@]}"; do
    # Convert to absolute path, handling both files and directories
    if [[ "$path" == /* ]]; then
        absolute_path="$path"
    else
        absolute_path="$(pwd)/$path"
    fi
    all_absolute_paths+=("$absolute_path")
done

# Find the longest common prefix among all absolute paths
common_root=$(find_common_prefix "${all_absolute_paths[@]}")

echo "Common root calculated: $common_root"

# If no common root found (e.g., paths are in /tmp and /etc),
# or if common_root is empty, set it to the current working directory,
# or the dirname of the first path if it's the only one.
if [ -z "$common_root" ]; then
    if [ ${#all_absolute_paths[@]} -gt 0 ]; then
        common_root=$(dirname "${all_absolute_paths[0]}")
        # If it's just a file, its common root might be itself, we need the directory.
        if [ -f "$common_root" ]; then
            common_root=$(dirname "$common_root")
        fi
    else
        common_root=$(pwd) # Fallback to current directory
    fi
fi

# Ensure common_root is an absolute path for display
if [[ ! "$common_root" == /* ]]; then
    common_root="$(pwd)/$common_root"
fi

# --- IGNORE LOGIC ---
declare -a ignore_patterns
declare -a find_prune_args
ignore_file_name=".repoignore"

# Find and load ignore patterns from the selected directory and the app's root
if [ -f "$common_root/$ignore_file_name" ]; then
    while IFS= read -r line; do
        ignore_patterns+=("$line")
    done < "$common_root/$ignore_file_name"
fi

script_dir=$(dirname "$(readlink -f "$0")")
if [ -f "$script_dir/$ignore_file_name" ]; then
    while IFS= read -r line; do
        ignore_patterns+=("$line")
    done < "$script_dir/$ignore_file_name"
fi

tree_ignore_pattern=""
for pattern in "${ignore_patterns[@]}"; do
    if [[ "$pattern" =~ ^\s*# ]] || [[ -z "$pattern" ]]; then
        continue
    fi
    clean_pattern=${pattern%/} # Remove trailing slash for matching
    
    # Build pattern for 'tree' command
    if [ -z "$tree_ignore_pattern" ]; then
        tree_ignore_pattern="$clean_pattern"
    else
        tree_ignore_pattern+="|$clean_pattern"
    fi

    # Build prune arguments for 'find' command
    if [ ${#find_prune_args[@]} -gt 0 ]; then
        find_prune_args+=(-o)
    fi
    find_prune_args+=(-name "$clean_pattern")
done
# --- END IGNORE LOGIC ---

echo "<file_map>"
echo "  $common_root"

# Get unique directories involved, including the common root itself
declare -A involved_dirs_map
for path in "${all_absolute_paths[@]}"; do
    current_dir="$path"
    while [[ "$current_dir" != "$common_root" && "$current_dir" != "/" && "$current_dir" != "." ]]; do
        involved_dirs_map["$(dirname "$current_dir")"]=1
        current_dir=$(dirname "$current_dir")
    done
done

# Sort the paths for consistent tree output. We need unique *files and directories*
# relative to the common root.
declare -a unique_items
for path in "${all_absolute_paths[@]}"; do
    # Add the path itself if it's a file, or its base directory if it's a directory
    if [ -f "$path" ] || [ -d "$path" ]; then
        # Check if the path is already covered by a parent directory
        local already_added=false
        for added_item in "${unique_items[@]}"; do
            if [[ "$path" == "$added_item"* ]]; then
                already_added=true
                break
            fi
        done
        if ! $already_added; then
            unique_items+=("$path")
        fi
    fi
done

# Sort unique items for consistent tree display
IFS=$'\n' sorted_unique_items=($(sort <<<"${unique_items[*]}"))
unset IFS

# Special handling for the tree generation to only include paths relevant to the input
# The tree generation logic for the file map is quite complex if you want to strictly
# show *only* the paths in the input and their necessary parent directories.
# A simpler approach for the tree is to just use the `tree` command if available,
# or simulate a full tree and then filter/mark the relevant files.
# For this prompt, let's simulate the structure by iterating through the input files
# and building the tree manually, focusing on the common root.

# To emulate the structure shown in the example, we need to pass the initial common_root
# and then generate the tree from there, potentially filtering.
# For simplicity and to match the output format, we'll iterate through the known paths
# and display their components relative to the common root.
# This requires a more sophisticated tree printing logic than a simple recursive `ls`.

# Let's use a simpler approach for tree generation that focuses on the given paths
# and constructs the tree level by level.

# Instead of a complex recursive `generate_tree`, we can build the tree based on the provided paths
declare -A tree_nodes
for abs_path in "${all_absolute_paths[@]}"; do
    # Remove common_root prefix and split by '/'
    relative_path="${abs_path#$common_root/}"
    IFS='/' read -ra path_parts <<< "$relative_path"

    current_node_path=""
    for i in "${!path_parts[@]}"; do
        part="${path_parts[$i]}"
        if [ -z "$current_node_path" ]; then
            current_node_path="$part"
        else
            current_node_path="$current_node_path/$part"
        fi
        tree_nodes["$current_node_path"]=1
    done
done

# Collect all unique paths (files and directories) that should be in the tree, sorted.
# This includes the original input files, and all their parent directories up to the common root.
declare -A full_tree_paths_map
for abs_path in "${all_absolute_paths[@]}"; do
    current_part="$abs_path"
    while [[ "$current_part" != "$common_root" ]] && [[ "$current_part" != "$(dirname "$common_root")" ]]; do
        full_tree_paths_map["$current_part"]=1
        current_part=$(dirname "$current_part")
    done
done

declare -a full_tree_paths
for p in "${!full_tree_paths_map[@]}"; do
    full_tree_paths+=("$p")
done

IFS=$'\n' sorted_full_tree_paths=($(sort <<<"${full_tree_paths[*]}"))
unset IFS

# Now, print the tree structure from the common_root
# This is a simplified tree printer for the specific output format.
# It's not a general `tree` command replacement.

# Print the root, then its children, etc.
# This part is tricky to get exactly right without a proper tree utility.
# We'll simulate by iterating through the sorted full paths and calculating indentation.

# Simplified visual tree generation:
# This part is highly dependent on the "tree" command's output style.
# Recreating that precisely in Bash is complex.
# A common way to get the tree output is to use the `tree` command itself.
# If `tree` is not available, we have to simulate it manually, which is error-prone.
# For this example, let's assume we want to show *only* the specific paths and their parents.
# The previous `generate_tree` function was a start. Let's refine it.

# Re-implementing generate_tree to ensure only relevant paths are shown.
# The previous generate_tree would show *all* files/dirs under common_root.
# We need to filter based on `all_absolute_paths`.

# Instead of using a complex tree generation for the map,
# let's rely on the structure of the input paths and their common root.
# Given the example output, the `tree` command is the most straightforward way.
# Let's assume the user has `tree` installed or provide instructions to install it.
# We'll build a temporary directory structure or use a simpler approach.

# If `tree` command is available, this is the easiest way to generate the file map.
# Otherwise, generating it manually in Bash is non-trivial for general cases.
# For the *exact* example format, a simple iterative approach is possible
# by finding common prefixes and printing components.

# Let's try to generate the tree visually by iterating through the paths and building the structure.
# This will not exactly match the `tree` command's full output for all files,
# but will focus on the specified paths and their hierarchy.

# Helper function for tree structure printing
print_tree_node() {
    local path="$1"
    local level="$2"
    local is_last="$3" # "true" or "false"
    local indent_prefix="$4"

    local node_name=$(basename "$path")
    local current_indent=""
    local branch_char="├── "
    local line_char="│   "

    if [ "$is_last" == "true" ]; then
        branch_char="└── "
        line_char="    "
    fi

    echo "${indent_prefix}${branch_char}${node_name}"
    echo "$line_char" # For vertical lines for sub-branches.

    # This recursive approach is difficult to manage with dynamic indentation.
    # The example output uses `tree` command's style.
    # The simplest way to achieve *that specific format* is indeed the `tree` command.
}

# The provided example output for file_map suggests the `tree` command was used.
# It lists *all* files and directories under `monitoring_bot`, not just the ones
# explicitly mentioned in the input string "path1/dir1,path2/file1,dir1/file2".
# Therefore, the script should identify a base directory from the input paths
# and then run `tree` on that directory.

# Let's refine `find_common_prefix` to find the base directory for `tree`.
# Given "path1/dir1,path2/file1,dir1/file2", if these are relative to a project root,
# say `/Users/denis/Repos/AI projects/discord-listener/v4/monitoring_bot`,
# then `find_common_prefix` should ideally return that.

# The current `find_common_prefix` gives a good start. Let's use it as the root for `tree`.
# If `tree` is not installed, the script will prompt the user.

# Generate File Map
echo "<file_map>"
if command -v tree &> /dev/null; then
    # Adjust common_root for tree command. It expects a directory.
    # If common_root is a file, use its dirname.
    if [ -f "$common_root" ]; then
        tree_root=$(dirname "$common_root")
    else
        tree_root="$common_root"
    fi

    echo "Directory for tree command: $tree_root"

    tree_args=(-a "$tree_root" --noreport -L 3 --charset=ascii)
    if [ -n "$tree_ignore_pattern" ]; then
        tree_args+=(-I "$tree_ignore_pattern")
    fi
    tree_output=$(tree "${tree_args[@]}")
    echo "$tree_output" | sed 's/^/  /'
else
    echo "  The 'tree' command is required to generate the file map. Please install it (e.g., 'sudo apt-get install tree' or 'brew install tree')."
    echo "  Alternatively, a simplified manual directory listing will be provided."
    # Fallback to a simpler directory listing if tree is not available
    echo "  $common_root"
    for abs_path in "${sorted_full_tree_paths[@]}"; do
        if [[ "$abs_path" == "$common_root" ]]; then
            continue
        fi
        relative_path="${abs_path#$common_root/}"
        # Count slashes to determine depth
        depth=$(echo "$relative_path" | awk -F'/' '{print NF-1}')
        indentation=""
        for ((i=0; i<depth; i++)); do
            indentation+="│   "
        done
        
        # Determine connector. This is still a simplification.
        if [ -d "$abs_path" ]; then
            echo "${indentation}├── ${basename "$abs_path"}  "
        else
            echo "${indentation}└── ${basename "$abs_path"}  "
        fi
    done
fi
echo "" # Blank line for spacing as in example
echo "</file_map>"

echo "" # Blank line for spacing

echo "<file_contents>"

# Store processed files to avoid duplicates and maintain order
declare -A processed_files_map
declare -a ordered_files

# Sort the input file paths to ensure consistent output order
IFS=$'\n' sorted_input_paths=($(sort <<<"${all_absolute_paths[*]}"))
unset IFS

for full_path in "${sorted_input_paths[@]}"; do
    if [ -f "$full_path" ]; then
        if [[ -z "${processed_files_map["$full_path"]}" ]]; then
            ordered_files+=("$full_path")
            processed_files_map["$full_path"]=1
        fi
    else
        # If it's a directory, find all files within it, respecting the ignore patterns
        find_command=(find "$full_path")
        if [ ${#find_prune_args[@]} -gt 0 ]; then
            find_command+=(\( "${find_prune_args[@]}" \) -prune -o)
        fi
        find_command+=(-type f -print0)

        while IFS= read -r -d $'\0'; do
            if [[ -f "$REPLY" ]]; then
                if [[ -z "${processed_files_map["$REPLY"]}" ]]; then
                    ordered_files+=("$REPLY")
                    processed_files_map["$REPLY"]=1
                fi
            fi
        done < <("${find_command[@]}" | sort -z)
    fi
done

# Sort the final list of files to process
IFS=$'\n' final_sorted_files=($(sort <<<"${ordered_files[*]}"))
unset IFS

for file_path in "${final_sorted_files[@]}"; do
    if [ -f "$file_path" ]; then
        echo "File: $file_path"
        file_type=$(get_file_extension_type "$file_path")
        echo "\`\`\`$file_type"
        if is_binary "$file_path"; then
            echo "[Binary file]"
        else
            cat "$file_path"
        fi
        echo "\`\`\`"
        echo "" # Add an empty line after each file content block as in the example
    fi
done

echo "</file_contents>" 