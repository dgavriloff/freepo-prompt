#include <iostream>
#include <fstream>
#include <vector>
#include <string>
#include <sstream>
#include <map>
#include <memory>
#include <filesystem>
#include <algorithm>

// Represents a node in the file system tree (either a file or a directory).
struct Node {
    std::string name;
    // Using a map ensures children are sorted alphabetically by name.
    std::map<std::string, std::unique_ptr<Node>> children; 
    bool isDirectory = false;

    Node(std::string n, bool isDir) : name(std::move(n)), isDirectory(isDir) {}
};

/**
 * @brief Inserts a path into the file system tree structure.
 * * @param roots A map holding the root nodes of all found directory trees.
 * @param path The filesystem path to insert.
 */
void insertPath(std::map<std::string, std::unique_ptr<Node>>& roots, const std::filesystem::path& path) {
    if (path.empty()) return;

    auto it = path.begin();
    if (it == path.end()) return;

    // Determine the root of the current path.
    std::string rootName = it->string();
    if (rootName == "." || rootName == "/") { // Handle relative and absolute paths
        it++;
        if (it == path.end()) return;
        rootName = it->string();
    }
    
    // Create the root node if it doesn't exist.
    if (roots.find(rootName) == roots.end()) {
        roots[rootName] = std::make_unique<Node>(rootName, true);
    }
    
    Node* current = roots[rootName].get();
    it++;

    // Traverse the path components and build the tree.
    for (; it != path.end(); ++it) {
        const std::string component = it->string();
        if (component.empty()) continue;

        if (current->children.find(component) == current->children.end()) {
            // Check if the current component is a directory in the actual filesystem.
            bool isDir = std::filesystem::is_directory(path.parent_path() / component) || 
                         (std::filesystem::is_directory(path) && it->string() == path.filename().string());
            
            // A more robust check for directories that might not have children listed yet
            if (!isDir && std::filesystem::exists(path) && std::filesystem::is_directory(path)) {
                 if(it->string() != path.filename().string()){
                     isDir = true;
                 }
            }


            current->children[component] = std::make_unique<Node>(component, isDir);
        }
        current = current->children[component].get();
    }
    // Final node in a path might be a directory, so update its status.
    if (std::filesystem::is_directory(path)) {
        current->isDirectory = true;
    }
}

/**
 * @brief Recursively generates the tree string for the <file_map> section.
 * * @param os The output stream to write to.
 * @param node The current node to process.
 * @param prefix The string prefix for drawing tree lines.
 * @param isLast True if this is the last child of its parent.
 */
void generateFileMapTree(std::ostream& os, const Node& node, const std::string& prefix, bool isLast) {
    os << prefix << (isLast ? "└── " : "├── ") << node.name << "\n";
    
    const std::string childPrefix = prefix + (isLast ? "    " : "│   ");
    
    auto it = node.children.begin();
    while (it != node.children.end()) {
        const auto& childNode = it->second;
        bool isLastChild = (++it == node.children.end());
        generateFileMapTree(os, *childNode, childPrefix, isLastChild);
    }
}

/**
 * @brief Checks if a file is likely a binary file.
 * * @param filePath The path to the file.
 * @return True if the file seems to be binary, false otherwise.
 */
bool isBinaryFile(const std::filesystem::path& filePath) {
    std::ifstream file(filePath, std::ios::binary);
    if (!file.is_open()) return false;

    char buffer[1024];
    file.read(buffer, sizeof(buffer));
    
    int readCount = file.gcount();
    for (int i = 0; i < readCount; ++i) {
        if (buffer[i] == '\0') {
            return true;
        }
    }
    return false;
}

/**
 * @brief Generates the <file_contents> section of the XML.
 * * @param os The output stream to write to.
 * @param paths A vector of all file paths to include.
 */
void generateFileContents(std::ostream& os, const std::vector<std::string>& paths) {
    for (const auto& pathStr : paths) {
        std::filesystem::path path(pathStr);
        if (!std::filesystem::is_regular_file(path)) continue;

        os << "<file path=\"" << pathStr << "\">\n";
        
        std::string extension = path.extension().string();
        if (!extension.empty()) {
            extension = extension.substr(1); // remove the dot
        } else {
            extension = "text"; // default
        }

        os << "```" << extension << "\n";
        
        if (isBinaryFile(path)) {
            os << "[Binary file]\n";
        } else {
            std::ifstream file(path);
            if (file.is_open()) {
                os << std::string(std::istreambuf_iterator<char>(file), std::istreambuf_iterator<char>());
            } else {
                os << "[Could not read file]\n";
            }
        }
        os << "```\n";
        os << "</file>\n";
    }
}


int main(int argc, char* argv[]) {
    if (argc != 2) {
        std::cerr << "Usage: " << argv[0] << " <path_to_file_list.txt>\n";
        return 1;
    }

    std::ifstream fileList(argv[1]);
    if (!fileList.is_open()) {
        std::cerr << "Error: Could not open file: " << argv[1] << "\n";
        return 1;
    }

    std::vector<std::string> paths;
    std::string line;
    while (std::getline(fileList, line)) {
        if (!line.empty()) {
            paths.push_back(line);
        }
    }

    std::map<std::string, std::unique_ptr<Node>> roots;
    for (const auto& p : paths) {
        if (std::filesystem::exists(p)) {
             insertPath(roots, std::filesystem::path(p));
        } else {
            std::cerr << "Warning: Path does not exist and will be skipped: " << p << "\n";
        }
    }

    // --- Generate XML Output ---
    std::cout << "<codex>\n";

    // --- <file_map> Section ---
    std::cout << "<file_map>\n";
    auto it = roots.begin();
    while (it != roots.end()) {
        const auto& rootNode = it->second;
        bool isLastRoot = (++it == roots.end());
        generateFileMapTree(std::cout, *rootNode, "", isLastRoot);
    }
    std::cout << "</file_map>\n";

    // --- <file_contents> Section ---
    std::cout << "<file_contents>\n";
    generateFileContents(std::cout, paths);
    std::cout << "</file_contents>\n";

    std::cout << "</codex>\n";

    return 0;
} 