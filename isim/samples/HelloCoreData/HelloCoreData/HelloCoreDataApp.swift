// Sample: Core Data + SwiftUI on isim, built from an Xcode project (HelloCoreData.xcodeproj) by `isim build`.
// The .xcdatamodeld is compiled to isim's model format and its "Class Definition" codegen makes Item/Folder.
import SwiftUI
import CoreData

@main
struct HelloCoreDataApp: App {
    let persistence = PersistenceController.shared
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(\.managedObjectContext, persistence.container.viewContext)
        }
    }
}
