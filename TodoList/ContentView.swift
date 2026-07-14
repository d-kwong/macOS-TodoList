import SwiftUI
import UniformTypeIdentifiers

// MARK: - Focus Management State Enum
enum FocusField: Hashable {
    case dummy // Invisible focus trap to prevent macOS auto-highlighting
    case task(id: UUID)
    case region(id: String)
}

// MARK: - Persistent Wrapper Data Model Struct
struct BoardData: Codable {
    var tasks: [TaskItem]
    var regionTitles: [String: String]
}

struct ContentView: View {
    @State private var tasks: [TaskItem] = []
    @State private var regionTitles: [String: String] = [
        TaskRegion.todo.rawValue: TaskRegion.todo.rawValue,
        TaskRegion.inProgress.rawValue: TaskRegion.inProgress.rawValue,
        TaskRegion.done.rawValue: TaskRegion.done.rawValue
    ]
    
    @FocusState private var activeFocus: FocusField?
    @State private var draggedTask: TaskItem? = nil
    @State private var isHoveringOverTrash: Bool = false
    @State private var currentCursorLocation: CGPoint = .zero

    var body: some View {
        GeometryReader { windowGeometry in
            ZStack(alignment: .topLeading) {
                
                // Focus Trap: Invisible field that steals auto-focus, fully pushed off-screen
                TextField("", text: .constant(""))
                    .textFieldStyle(.plain) // Kills the macOS blue focus ring completely
                    .frame(width: 1, height: 1)
                    .opacity(0.001)
                    .position(x: -1000, y: -1000) // Throws the element completely off-screen
                    .focused($activeFocus, equals: .dummy)
                    .allowsHitTesting(false)
                
                // Background Layer Drop Target & Global Click-Off
                GeometryReader { bgGeo in
                    Color.white
                        .ignoresSafeArea()
                        .onTapGesture {
                            activeFocus = .dummy
                        }
                        .onDrop(of: [.text], delegate: BackgroundDropDelegate(
                            draggedTask: $draggedTask,
                            currentCursorLocation: $currentCursorLocation,
                            origin: bgGeo.frame(in: .named("WindowSpace")).origin
                        ))
                }

                VStack {
                    HStack(spacing: 24) {
                        ForEach(TaskRegion.allCases, id: \.self) { region in
                            TaskColumnView(
                                region: region,
                                tasks: $tasks,
                                regionTitles: $regionTitles,
                                activeFocus: _activeFocus,
                                draggedTask: $draggedTask,
                                isHoveringOverTrash: $isHoveringOverTrash,
                                currentCursorLocation: $currentCursorLocation,
                                borderColor: region.themeColor,
                                onAddTask: region == .todo ? { spawnUntitledTask() } : nil
                            )
                        }
                    }
                    .padding(.horizontal, 24)
                    .padding(.vertical, 24)
                }

                // Dynamic Drag Overlay
                if let task = draggedTask {
                    ZStack(alignment: .topLeading) {
                        if task.title.isEmpty && !task.hasBeenEdited {
                            Text("untitled")
                                .foregroundColor(.gray.opacity(0.5))
                        }
                        
                        Text(task.title.isEmpty ? " " : task.title)
                            .foregroundColor(.black)
                            .lineLimit(nil)
                    }
                    .padding()
                    .frame(width: ((windowGeometry.size.width - 96) / 3) - 24, alignment: .topLeading)
                    .frame(minHeight: 44)
                    .background(isHoveringOverTrash ? Color(white: 0.92) : Color.white)
                    .cornerRadius(8)
                    .shadow(color: Color.black.opacity(0.20), radius: 5, x: 0, y: 3)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(isHoveringOverTrash ? Color(red: 220/255, green: 20/255, blue: 60/255) : Color.clear, lineWidth: 2)
                    )
                    .position(x: currentCursorLocation.x, y: currentCursorLocation.y)
                    .allowsHitTesting(false)
                }
            }
            .coordinateSpace(name: "WindowSpace")
        }
        .frame(minWidth: 700, maxWidth: .infinity, minHeight: 450, maxHeight: .infinity)
        .onAppear {
            loadBoardData()
            DispatchQueue.main.async {
                activeFocus = .dummy
            }
        }
        .onChange(of: tasks) { _, _ in saveBoardData() }
        .onChange(of: regionTitles) { _, _ in saveBoardData() }
    }

    private func spawnUntitledTask() {
        let newTodo = TaskItem(title: "", region: .todo, hasBeenEdited: false)
        tasks.append(newTodo)
    }
    
    private func getSaveURL() -> URL {
        let paths = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)
        return paths[0].appendingPathComponent("SimpleTodo_Save.json")
    }

    private func saveBoardData() {
        do {
            let board = BoardData(tasks: tasks, regionTitles: regionTitles)
            let data = try JSONEncoder().encode(board)
            try data.write(to: getSaveURL())
        } catch {
            print("Failed to save board contents: \(error.localizedDescription)")
        }
    }

    private func loadBoardData() {
        let url = getSaveURL()
        guard FileManager.default.fileExists(atPath: url.path) else {
            setupInitialFallbackState()
            return
        }
        
        do {
            let data = try Data(contentsOf: url)
            if let decodedBoard = try? JSONDecoder().decode(BoardData.self, from: data) {
                self.tasks = decodedBoard.tasks
                for (key, value) in decodedBoard.regionTitles {
                    self.regionTitles[key] = value
                }
            } else if let legacyTasks = try? JSONDecoder().decode([TaskItem].self, from: data) {
                self.tasks = legacyTasks
            }
        } catch {
            setupInitialFallbackState()
        }
    }
    
    private func setupInitialFallbackState() {
        if tasks.isEmpty {
            tasks = [TaskItem(title: "Add a task using +", region: .todo, hasBeenEdited: true)]
        }
    }
}

// MARK: - Column Layout View
struct TaskColumnView: View {
    let region: TaskRegion
    @Binding var tasks: [TaskItem]
    @Binding var regionTitles: [String: String]
    @FocusState var activeFocus: FocusField?
    @Binding var draggedTask: TaskItem?
    @Binding var isHoveringOverTrash: Bool
    @Binding var currentCursorLocation: CGPoint
    let borderColor: Color
    let onAddTask: (() -> Void)?

    @State private var insertionIndex: Int? = nil

    var body: some View {
        let columnTasks = tasks.filter { $0.region == region && $0.id != draggedTask?.id }

        VStack(alignment: .leading) {
            ColumnHeaderView(
                region: region,
                regionTitles: $regionTitles,
                activeFocus: _activeFocus,
                isHoveringOverTrash: $isHoveringOverTrash,
                tasks: $tasks,
                draggedTask: $draggedTask,
                currentCursorLocation: $currentCursorLocation,
                onAddTask: onAddTask
            )

            ZStack(alignment: .top) {
                GeometryReader { dropZoneGeo in
                    Color.white.opacity(0.001)
                        .onDrop(of: [.text], delegate: ColumnDropDelegate(
                            region: region,
                            tasks: $tasks,
                            draggedTask: $draggedTask,
                            insertionIndex: $insertionIndex,
                            currentCursorLocation: $currentCursorLocation,
                            origin: dropZoneGeo.frame(in: .named("WindowSpace")).origin
                        ))
                        .onTapGesture {
                            activeFocus = .dummy
                        }
                }

                ScrollView {
                    VStack(spacing: 0) {
                        if insertionIndex == 0 {
                            RoundedRectangle(cornerRadius: 2)
                                .fill(Color(.systemBlue))
                                .frame(height: 3)
                                .padding(.vertical, 6)
                        }

                        ForEach(Array(columnTasks.enumerated()), id: \.element.id) { index, task in
                            TaskCardView(
                                task: task,
                                tasks: $tasks,
                                activeFocus: _activeFocus,
                                draggedTask: $draggedTask
                            )

                            if insertionIndex == index + 1 {
                                RoundedRectangle(cornerRadius: 2)
                                    .fill(Color(.systemBlue))
                                    .frame(height: 3)
                                    .padding(.bottom, 12)
                            }
                        }
                    }
                    .padding(.horizontal, 2)
                    .padding(.vertical, 4)
                }
                .allowsHitTesting(true)
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(
            Color.black.opacity(0.03)
                .contentShape(Rectangle())
                .onTapGesture {
                    activeFocus = .dummy
                }
        )
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(borderColor, lineWidth: 1)
        )
    }
}

// MARK: - Column Header Component
struct ColumnHeaderView: View {
    let region: TaskRegion
    @Binding var regionTitles: [String: String]
    @FocusState var activeFocus: FocusField?
    @Binding var isHoveringOverTrash: Bool
    @Binding var tasks: [TaskItem]
    @Binding var draggedTask: TaskItem?
    @Binding var currentCursorLocation: CGPoint
    let onAddTask: (() -> Void)?

    var body: some View {
        HStack {
            TextField("", text: Binding(
                get: { self.regionTitles[region.rawValue] ?? region.rawValue },
                set: { self.regionTitles[region.rawValue] = $0 }
            ))
            .font(.title3)
            .bold()
            .foregroundColor(.black)
            .textFieldStyle(.plain)
            .lineLimit(1)
            .focused($activeFocus, equals: .region(id: region.rawValue))
            .onSubmit {
                activeFocus = .dummy
            }
            
            Spacer()
            
            if let onAddTask = onAddTask {
                Button(action: onAddTask) {
                    Image(systemName: "plus")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(.gray)
                }
                .buttonStyle(.plain)
                .help("Add new task")
            }
            
            if region == .done {
                ZStack {
                    GeometryReader { trashGeo in
                        Color.white.opacity(0.001)
                            .onDrop(of: [.text], delegate: TrashDropDelegate(
                                tasks: $tasks,
                                draggedTask: $draggedTask,
                                isHoveringOverTrash: $isHoveringOverTrash,
                                currentCursorLocation: $currentCursorLocation,
                                origin: trashGeo.frame(in: .named("WindowSpace")).origin
                            ))
                    }
                    
                    Image(systemName: "trash")
                        .font(.system(size: 14, weight: .regular))
                        .foregroundColor(isHoveringOverTrash ? Color(red: 220/255, green: 20/255, blue: 60/255) : .gray)
                        .allowsHitTesting(false)
                }
                .frame(width: 32, height: 32)
            }
        }
        .frame(minHeight: 32)
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.bottom, 6)
    }
}

// MARK: - Task Card Row View
struct TaskCardView: View {
    let task: TaskItem
    @Binding var tasks: [TaskItem]
    @FocusState var activeFocus: FocusField?
    @Binding var draggedTask: TaskItem?

    var body: some View {
        VStack(spacing: 0) {
            ZStack(alignment: .topLeading) {
                if task.title.isEmpty && !task.hasBeenEdited {
                    Text("untitled")
                        .foregroundColor(.gray.opacity(0.5))
                        .allowsHitTesting(false)
                }
                
                TextField("", text: binding(for: task.id), axis: .vertical)
                    .focused($activeFocus, equals: .task(id: task.id))
                    .textFieldStyle(.plain)
                    .onChange(of: activeFocus) { _, newValue in
                        if newValue == .task(id: task.id) {
                            if let idx = tasks.firstIndex(where: { $0.id == task.id }) {
                                tasks[idx].hasBeenEdited = true
                            }
                        }
                    }
                    .onSubmit {
                        activeFocus = .dummy
                    }
            }
            .padding()
            .frame(maxWidth: .infinity, alignment: .topLeading)
            .frame(minHeight: 44)
            .background(Color.white)
            .foregroundColor(.black)
            .cornerRadius(8)
            .shadow(color: Color.black.opacity(0.15), radius: 4, x: 0, y: 2)
        }
        .onDrag({
            self.draggedTask = task
            return NSItemProvider(object: task.id.uuidString as NSString)
        }, preview: {
            Color.clear
                .frame(width: 1, height: 1)
        })
        .padding(.bottom, 12)
    }

    private func binding(for id: UUID) -> Binding<String> {
        Binding(
            get: { self.tasks.first(where: { $0.id == id })?.title ?? "" },
            set: { newValue in
                if let index = self.tasks.firstIndex(where: { $0.id == id }) {
                    self.tasks[index].title = newValue
                }
            }
        )
    }
}

// MARK: - Drop Delegates

struct BackgroundDropDelegate: DropDelegate {
    @Binding var draggedTask: TaskItem?
    @Binding var currentCursorLocation: CGPoint
    let origin: CGPoint

    func dropUpdated(info: DropInfo) -> DropProposal? {
        currentCursorLocation = CGPoint(x: info.location.x + origin.x, y: info.location.y + origin.y)
        return DropProposal(operation: .move)
    }
    
    func performDrop(info: DropInfo) -> Bool {
        self.draggedTask = nil
        return false
    }
}

struct TrashDropDelegate: DropDelegate {
    @Binding var tasks: [TaskItem]
    @Binding var draggedTask: TaskItem?
    @Binding var isHoveringOverTrash: Bool
    @Binding var currentCursorLocation: CGPoint
    let origin: CGPoint

    func dropEntered(info: DropInfo) {
        isHoveringOverTrash = true
    }

    func dropUpdated(info: DropInfo) -> DropProposal? {
        currentCursorLocation = CGPoint(x: info.location.x + origin.x, y: info.location.y + origin.y)
        return DropProposal(operation: .move)
    }

    func dropExited(info: DropInfo) {
        isHoveringOverTrash = false
    }

    func performDrop(info: DropInfo) -> Bool {
        guard let taskToDelete = draggedTask else {
            isHoveringOverTrash = false
            return false
        }

        if let index = tasks.firstIndex(where: { $0.id == taskToDelete.id }) {
            tasks.remove(at: index)
        }

        self.draggedTask = nil
        self.isHoveringOverTrash = false
        return true
    }
}

struct ColumnDropDelegate: DropDelegate {
    let region: TaskRegion
    @Binding var tasks: [TaskItem]
    @Binding var draggedTask: TaskItem?
    @Binding var insertionIndex: Int?
    @Binding var currentCursorLocation: CGPoint
    let origin: CGPoint

    func dropEntered(info: DropInfo) {
        calculateInsertionIndex(info: info)
    }

    func dropUpdated(info: DropInfo) -> DropProposal? {
        calculateInsertionIndex(info: info)
        
        currentCursorLocation = CGPoint(x: info.location.x + origin.x, y: info.location.y + origin.y)
        return DropProposal(operation: .move)
    }

    func dropExited(info: DropInfo) {
        insertionIndex = nil
    }

    func performDrop(info: DropInfo) -> Bool {
        guard let taskToMove = draggedTask else {
            insertionIndex = nil
            return false
        }

        if let sourceIndex = tasks.firstIndex(where: { $0.id == taskToMove.id }) {
            tasks.remove(at: sourceIndex)
        }

        let columnTasks = tasks.filter { $0.region == region && $0.id != taskToMove.id }
        let targetIndex = insertionIndex ?? columnTasks.count

        var updatedTask = taskToMove
        updatedTask.region = region

        if targetIndex >= columnTasks.count {
            tasks.append(updatedTask)
        } else {
            let targetTaskInGlobal = columnTasks[targetIndex]
            if let globalIndex = tasks.firstIndex(where: { $0.id == targetTaskInGlobal.id }) {
                tasks.insert(updatedTask, at: globalIndex)
            } else {
                tasks.append(updatedTask)
            }
        }

        self.draggedTask = nil
        self.insertionIndex = nil
        return true
    }

    private func calculateInsertionIndex(info: DropInfo) {
        let columnTasks = tasks.filter { $0.region == region && $0.id != draggedTask?.id }
        if columnTasks.isEmpty {
            insertionIndex = 0
            return
        }

        let estimateCardHeight: CGFloat = 56.0
        let spaceBetween: CGFloat = 12.0
        let totalStepHeight = estimateCardHeight + spaceBetween

        let dropY = info.location.y
        var calculatedIndex = Int((dropY / totalStepHeight).rounded(.toNearestOrAwayFromZero))
        
        if calculatedIndex < 0 { calculatedIndex = 0 }
        if calculatedIndex > columnTasks.count { calculatedIndex = columnTasks.count }

        insertionIndex = calculatedIndex
    }
}
