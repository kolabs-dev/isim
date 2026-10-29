// isim BackgroundTasks for Objective-C (sdk-src/Frameworks/BackgroundTasks): the classes carry Apple's Objective-C names
// and these members Apple's selectors. A launch handler registered with a dispatch queue runs on that queue.
import Foundation
import Darwin

extension BGTaskRequest {
    @objc(identifier) var _objc_identifier: String { identifier }
    @objc(earliestBeginDate) var _objc_earliestBeginDate: Date? { get { earliestBeginDate } set { earliestBeginDate = newValue } }
}
extension BGAppRefreshTaskRequest {
    @objc(initWithIdentifier:) convenience init(_objcIdentifier identifier: String) { self.init(identifier: identifier) }
}
extension BGProcessingTaskRequest {
    @objc(initWithIdentifier:) convenience init(_objcIdentifier identifier: String) { self.init(identifier: identifier) }
    @objc(requiresNetworkConnectivity) var _objc_requiresNetworkConnectivity: Bool {
        get { requiresNetworkConnectivity } set { requiresNetworkConnectivity = newValue }
    }
    @objc(requiresExternalPower) var _objc_requiresExternalPower: Bool { get { requiresExternalPower } set { requiresExternalPower = newValue } }
}
extension BGTask {
    @objc(identifier) var _objc_identifier: String { identifier }
    @objc(expirationHandler) var _objc_expirationHandler: (@convention(block) () -> Void)? {
        get { guard let h = expirationHandler else { return nil }; return { h() } }
        set { if let n = newValue { expirationHandler = { n() } } else { expirationHandler = nil } }
    }
    @objc(setTaskCompletedWithSuccess:) func _objc_setTaskCompleted(_ success: Bool) { setTaskCompleted(success: success) }
}
extension BGTaskScheduler {
    @objc(sharedScheduler) static var _objc_shared: BGTaskScheduler { shared }
    @objc(registerForTaskWithIdentifier:usingQueue:launchHandler:)
    func _objc_register(_ identifier: String, queue: dispatch_queue_t?, launchHandler: @escaping @convention(block) (BGTask) -> Void) -> Bool {
        guard let queue else { return register(forTaskWithIdentifier: identifier, using: nil, launchHandler: { launchHandler($0) }) }
        dispatch_retain(UnsafeMutableRawPointer(queue))         // kept with the registration (ARC releases the caller's)
        return register(forTaskWithIdentifier: identifier, using: nil, launchHandler: { task in dispatch_async(queue) { launchHandler(task) } })
    }
    @objc(submitTaskRequest:error:) func _objc_submit(_ taskRequest: BGTaskRequest) throws { try submit(taskRequest) }
    @objc(cancelTaskRequestWithIdentifier:) func _objc_cancel(_ identifier: String) { cancel(taskRequestWithIdentifier: identifier) }
    @objc(cancelAllTaskRequests) func _objc_cancelAll() { cancelAllTaskRequests() }
    @objc(getPendingTaskRequestsWithCompletionHandler:)
    func _objc_getPending(_ completionHandler: @escaping @convention(block) ([BGTaskRequest]) -> Void) {
        getPendingTaskRequests { completionHandler($0) }
    }
}

@available(iOS 26.0, *)
extension BGContinuedProcessingTaskRequest {
    @objc(initWithIdentifier:title:subtitle:) convenience init(_objcIdentifier identifier: String, title: String, subtitle: String) {
        self.init(identifier: identifier, title: title, subtitle: subtitle)
    }
    @objc(title) var _objc_title: String { get { title } set { title = newValue } }
    @objc(subtitle) var _objc_subtitle: String { get { subtitle } set { subtitle = newValue } }
    @objc(strategy) var _objc_strategy: Int { get { strategy.rawValue } set { strategy = SubmissionStrategy(rawValue: newValue) ?? .queue } }
    @objc(requiredResources) var _objc_requiredResources: Int {
        get { requiredResources.rawValue } set { requiredResources = Resources(rawValue: newValue) }
    }
}
@available(iOS 26.0, *)
extension BGContinuedProcessingTask {
    @objc(title) var _objc_title: String { title }
    @objc(subtitle) var _objc_subtitle: String { subtitle }
    @objc(updateTitle:subtitle:) func _objc_updateTitle(_ title: String, subtitle: String) { updateTitle(title, subtitle: subtitle) }
}
@available(iOS 26.0, *)
extension BGTaskScheduler {
    @objc(supportedResources) class var _objc_supportedResources: Int { supportedResources.rawValue }
}
