// Sample: Observation (iOS 17) on isim — an @Observable store in @State, passed with .environment(_:),
// read with @Environment(Store.self), edited through @Bindable, and views that update when it changes.
import SwiftUI

@Observable
final class Task: Identifiable {
    let id = UUID()
    var title: String
    var done = false
    init(_ title: String) { self.title = title }
}

@Observable
final class Store {
    var tasks = [Task("Buy milk"), Task("Walk the dog")]
    var draft = ""
    var remaining: Int { tasks.filter { !$0.done }.count }
    func add() {
        guard !draft.isEmpty else { return }
        tasks.append(Task(draft)); print("added \(draft)"); draft = ""
    }
}

@main
struct HelloObservationApp: App {
    @State private var store = Store()
    var body: some Scene { WindowGroup { TaskList().environment(store) } }
}

struct TaskList: View {
    @Environment(Store.self) private var store
    var body: some View {
        @Bindable var store = store
        NavigationStack {
            List {
                Section {
                    HStack {
                        TextField("New task", text: $store.draft).accessibilityIdentifier("draft")
                        Button("Add") { store.add() }.accessibilityIdentifier("add")
                    }
                }
                Section("Tasks") {
                    ForEach(store.tasks) { task in TaskRow(task: task) }
                }
                Section { Text("\(store.remaining) remaining").accessibilityIdentifier("remaining") }
            }
            .navigationTitle("Tasks")
        }
        .onChange(of: store.remaining) { _, n in print("remaining \(n)") }
    }
}

struct TaskRow: View {
    @Bindable var task: Task
    var body: some View {
        Toggle(task.title, isOn: $task.done).accessibilityIdentifier("task-" + task.title.replacingOccurrences(of: " ", with: "_"))
    }
}
