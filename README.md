# Native macOS Kanban Board: TodoList

<img width="800" height="520" alt="TodoList Demo" src="https://github.com/user-attachments/assets/6fbc8baa-39ed-46a7-aa20-3ae1a7a78dfb" />

A lightweight, native macOS Kanban board built entirely in SwiftUI. This project was built to explore complex Drag & Drop mechanics, unified coordinate spaces, and local data persistence in modern Apple development.

## ✨ Features
* **Custom Drag & Drop Engine:** Bypasses standard macOS ghosting for a 1:1 custom view tracker that follows the cursor seamlessly across the window.
* **Inline Editing & Focus Management:** Invisible focus traps prevent macOS auto-highlighting, allowing for a clean, click-to-edit experience for both task cards and column headers.
* **Fluid Deletion Mechanics:** Drop targets automatically detect coordinate intersections to provide dynamic visual feedback (crimson borders) before deletion.
* **Persistent Local Storage:** Automatically encodes board state (both custom column titles and task data) to a local JSON file, ensuring data survives app restarts.

## 🏗️ Architecture & Concepts Learned
I built this to master the following concepts:
1. **Coordinate Space Normalization:** Used `.coordinateSpace(name: "WindowSpace")` and `GeometryReader` to map local view boundaries (columns, margins, trash icon) into a single, unified global grid, preventing mathematical offset bugs during drag operations.
2. **DropDelegates:** Handled complex state mutations by passing bindings deeply into custom `DropDelegate` structs, allowing the background layer to "catch" dropped items and return them to their original location.
3. **Data Serialization (Codable):** Designed a `BoardData` wrapper struct to safely encode and decode arrays of custom UUID-tagged structs into JSON format.

## 🚀 How to Run Locally
1. Clone the repository: `git clone https://github.com/d-kwong/macOS-TodoList.git`
2. Open `TodoList.xcodeproj` in Xcode 15+.
3. Select "My Mac" as the run destination.
4. Hit `Cmd + R` to build and run.

*Built with Swift 5 & SwiftUI.*
