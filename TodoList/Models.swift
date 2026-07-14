import SwiftUI // Make sure SwiftUI is imported at the top of this file for Color support

struct TaskItem: Identifiable, Codable, Equatable {
    let id: UUID
    var title: String
    var region: TaskRegion
    var hasBeenEdited: Bool

    init(id: UUID = UUID(), title: String, region: TaskRegion, hasBeenEdited: Bool = false) {
        self.id = id
        self.title = title
        self.region = region
        self.hasBeenEdited = hasBeenEdited
    }
}

enum TaskRegion: String, Codable, CaseIterable {
    case todo = "To Do"
    case inProgress = "In Progress"
    case done = "Done"

    // Moving this property here ensures Xcode compiles it natively across all files
    var themeColor: Color {
        switch self {
        case .todo:
            return Color(red: 255/255, green: 95/255, blue: 86/255)
        case .inProgress:
            return Color(red: 255/255, green: 189/255, blue: 46/255)
        case .done:
            return Color(red: 39/255, green: 201/255, blue: 63/255)
        }
    }
}
