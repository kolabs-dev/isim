// Sample: networking on isim — URLSession with async/await and completion handlers, JSONDecoder, cookies
// (sign in, then an authenticated request), HTTP status and URLError handling, a WebSocket echo,
// Combine's dataTaskPublisher and NWPathMonitor.
// The server is server.py next to this file; pass its address as a launch argument:
//   python3 samples/HelloNetwork/server.py 8765 &
//   isim run out/apps/HelloNetwork.app -server http://127.0.0.1:8765
import SwiftUI
import Combine
import Network

struct Todo: Decodable, Identifiable { let id: Int; let title: String; let done: Bool }
struct Me: Decodable { let user: String }

@MainActor
final class NetworkModel: ObservableObject {
    @Published var path = "checking…"
    @Published var todos: [Todo] = []
    @Published var todosStatus = "loading…"
    @Published var message = "loading…"
    @Published var account = "signed out"
    @Published var errorText = "—"
    @Published var socketText = "—"
    @Published var combineText = "—"

    let base: URL
    let monitor = NWPathMonitor()
    var cancellables = Set<AnyCancellable>()
    var socket: URLSessionWebSocketTask?

    init() {
        base = URL(string: UserDefaults.standard.string(forKey: "server") ?? "http://127.0.0.1:8765")!
        print("server \(base.absoluteString)")
        monitor.pathUpdateHandler = { [weak self] p in
            let text = p.status == .satisfied ? "online" + (p.usesInterfaceType(.wifi) ? " (Wi-Fi)" : p.usesInterfaceType(.wiredEthernet) ? " (Ethernet)" : "") : "offline"
            print("path \(p.status)")
            Task { @MainActor in self?.path = text }
        }
        monitor.start(queue: DispatchQueue(label: "path"))
    }

    /// async/await + JSONDecoder
    func loadTodos() async {
        do {
            let (data, response) = try await URLSession.shared.data(from: base.appending(path: "todos"))
            guard (response as? HTTPURLResponse)?.statusCode == 200 else { todosStatus = "bad response"; return }
            todos = try JSONDecoder().decode([Todo].self, from: data)
            todosStatus = "\(todos.filter(\.done).count) of \(todos.count) done"
            print("todos \(todos.count) \(todos.map(\.title).joined(separator: ","))")
        } catch {
            todosStatus = error.localizedDescription
            print("todos error \(error)")
        }
    }

    /// completion handler (runs on URLSession's background delegate queue)
    func loadMessage() {
        URLSession.shared.dataTask(with: base.appending(path: "message")) { data, response, error in
            let text = data.flatMap { String(data: $0, encoding: .utf8) } ?? "error: \(error?.localizedDescription ?? "?")"
            print("message \(text) main=\(Thread.isMainThread)")
            DispatchQueue.main.async { self.message = text }
        }.resume()
    }

    /// POST JSON, receive a cookie, then an authenticated GET that sends it back
    func signIn() async {
        var request = URLRequest(url: base.appending(path: "login"))
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try? JSONSerialization.data(withJSONObject: ["user": "ada"])
        do {
            _ = try await URLSession.shared.data(for: request)
            let (data, response) = try await URLSession.shared.data(from: base.appending(path: "me"))
            let status = (response as? HTTPURLResponse)?.statusCode ?? 0
            let me = try? JSONDecoder().decode(Me.self, from: data)
            account = status == 200 ? "signed in as \(me?.user ?? "?")" : "HTTP \(status)"
            print("account \(account)")
        } catch { account = "error \((error as? URLError)?.code.rawValue ?? 0)" }
    }

    func fetchServerError() async {
        do {
            let (_, response) = try await URLSession.shared.data(from: base.appending(path: "status/503"))
            let code = (response as! HTTPURLResponse).statusCode
            errorText = "HTTP \(code) \(HTTPURLResponse.localizedString(forStatusCode: code))"
        } catch { errorText = "\(error)" }
        print("error \(errorText)")
    }

    func fetchUnreachable() async {
        do {
            _ = try await URLSession.shared.data(from: URL(string: "http://127.0.0.1:1/")!)
            errorText = "unexpected success"
        } catch let error as URLError where error.code == .cannotConnectToHost {
            errorText = "cannot connect (\(error.code.rawValue))"
        } catch { errorText = "\(error)" }
        print("error \(errorText)")
    }

    func echo() {
        var c = URLComponents(url: base, resolvingAgainstBaseURL: false)!
        c.scheme = base.scheme == "https" ? "wss" : "ws"
        c.path = "/ws"
        let task = URLSession.shared.webSocketTask(with: c.url!)
        socket = task
        task.resume()
        task.send(.string("hello isim")) { error in if let error { print("ws send error \(error)") } }
        task.receive { result in
            let text: String
            switch result {
            case .success(.string(let s)): text = s
            case .success(.data(let d)): text = "\(d.count) bytes"
            case .failure(let e): text = "error \(e.localizedDescription)"
            @unknown default: text = "?"
            }
            print("ws \(text)")
            DispatchQueue.main.async { self.socketText = text }
            task.cancel(with: .normalClosure, reason: nil)
        }
    }

    func combineFetch() {
        URLSession.shared.dataTaskPublisher(for: base.appending(path: "todos"))
            .tryMap { try JSONDecoder().decode([Todo].self, from: $0.data) }
            .receive(on: DispatchQueue.main)
            .sink(receiveCompletion: { if case .failure(let e) = $0 { self.combineText = "\(e)" } },
                  receiveValue: { todos in
                      self.combineText = "\(todos.count) todos via Combine"
                      print("combine \(todos.count)")
                  })
            .store(in: &cancellables)
    }
}

@main
struct HelloNetworkApp: App {
    @StateObject private var model = NetworkModel()
    var body: some Scene { WindowGroup { ContentView().environmentObject(model) } }
}

struct ContentView: View {
    @EnvironmentObject var model: NetworkModel
    var body: some View {
        NavigationStack {
            List {
                Section("Connection") {
                    LabeledContent("Network", value: model.path)
                    LabeledContent("Server", value: model.base.host ?? "")
                }
                Section("Todos · async/await") {
                    ForEach(model.todos) { t in
                        HStack {
                            Image(systemName: t.done ? "checkmark.circle.fill" : "circle").foregroundStyle(t.done ? .green : .secondary)
                            Text(t.title)
                        }
                    }
                    Text(model.todosStatus).foregroundStyle(.secondary)
                }
                Section("Message · completion handler") {
                    Text(model.message).accessibilityIdentifier("message")
                    Button("Reload") { model.loadMessage() }.accessibilityIdentifier("reload")
                }
                Section("Cookies") {
                    Text(model.account).accessibilityIdentifier("account")
                    Button("Sign In") { Task { await model.signIn() } }.accessibilityIdentifier("signin")
                }
                Section("Errors") {
                    Text(model.errorText).accessibilityIdentifier("errors")
                    Button("Server Error") { Task { await model.fetchServerError() } }.accessibilityIdentifier("http503")
                    Button("Unreachable Host") { Task { await model.fetchUnreachable() } }.accessibilityIdentifier("unreachable")
                }
                Section("WebSocket & Combine") {
                    Text(model.socketText).accessibilityIdentifier("socket")
                    Button("Echo") { model.echo() }.accessibilityIdentifier("echo")
                    Text(model.combineText).accessibilityIdentifier("combine")
                    Button("Fetch with Combine") { model.combineFetch() }.accessibilityIdentifier("combinefetch")
                }
            }
            .navigationTitle("Network")
        }
        .task {
            await model.loadTodos()
            model.loadMessage()
        }
    }
}
