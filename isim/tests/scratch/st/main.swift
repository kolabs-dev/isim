import SwiftUI
@main struct ST: App {
    var body: some Scene { WindowGroup { V() } }
}
struct V: View {
    var body: some View {
        VStack {
            HStack { Text("LEVELS").font(.system(size: 22, weight: .bold)); Spacer(); Text("302").padding(8).background(Color.gray) }.padding()
            ScrollViewReader { proxy in
                ScrollView {
                    VStack(spacing: 0) {
                        ForEach((1...40).reversed(), id: \.self) { n in
                            Text("Row \(n)").frame(height: 60).id(n)
                        }
                    }
                }
                .onAppear { proxy.scrollTo(2, anchor: .center) }
            }
        }
    }
}
