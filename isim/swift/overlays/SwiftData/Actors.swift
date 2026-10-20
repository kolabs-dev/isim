// isim SwiftData: model actors — an actor with its own ModelContext, run on a serial executor (a dispatch queue), so
// models are read and written off the main actor. @ModelActor generates the executor, the container and
// init(modelContainer:), as Apple's macro does.
import Foundation
import Dispatch

/// What runs a model context's work.
public protocol ModelExecutor: AnyObject, Sendable {
    var modelContext: ModelContext { get }
}

/// A model executor that is also a serial executor (an actor can run on it).
public protocol SerialModelExecutor: ModelExecutor, SerialExecutor {}

/// isim's serial model executor: the context's work runs on one dispatch queue.
public final class DefaultSerialModelExecutor: SerialModelExecutor, @unchecked Sendable {
    public let modelContext: ModelContext
    private let queue: DispatchQueue
    public init(modelContext: ModelContext) {
        self.modelContext = modelContext
        queue = DispatchQueue(label: "SwiftData.DefaultSerialModelExecutor")
    }
    public func enqueue(_ job: consuming ExecutorJob) {
        let unowned = UnownedJob(job)
        let executor = asUnownedSerialExecutor()
        queue.async { unowned.runSynchronously(on: executor) }
    }
    public func asUnownedSerialExecutor() -> UnownedSerialExecutor { UnownedSerialExecutor(ordinary: self) }
}

/// An actor that works with models in its own context.
public protocol ModelActor: Actor {
    nonisolated var modelExecutor: any ModelExecutor { get }
    nonisolated var modelContainer: ModelContainer { get }
}

extension ModelActor {
    /// runs on the model executor's queue
    public nonisolated var unownedExecutor: UnownedSerialExecutor {
        (modelExecutor as! any SerialModelExecutor).asUnownedSerialExecutor()
    }
    public var modelContext: ModelContext { modelExecutor.modelContext }
    /// the model with that identifier in the actor's context (nil when it is not a T)
    public subscript<T: PersistentModel>(id: PersistentIdentifier, as as: T.Type) -> T? {
        if let m: T = modelContext.registeredModel(for: id) { return m }
        return modelContext._find(id) as? T
    }
}

@attached(member, names: named(modelExecutor), named(modelContainer), named(init))
@attached(extension, conformances: ModelActor)
public macro ModelActor() = #externalMacro(module: "SwiftDataMacros", type: "ModelActorMacro")
