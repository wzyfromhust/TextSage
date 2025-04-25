import SwiftUI

struct ContentView: View {
    @State private var selectedTab: Int = 0
    @State private var showSettings: Bool = false
    
    var body: some View {
        VStack(spacing: 0) {
            // 顶部栏
            HStack {
                Text("选中即问")
                    .font(.headline)
                
                Spacer()
                
                Button(action: {
                    showSettings = true
                }) {
                    Image(systemName: "gear")
                        .font(.system(size: 16))
                }
                .buttonStyle(PlainButtonStyle())
                .sheet(isPresented: $showSettings) {
                    SettingsView()
                }
            }
            .padding()
            .background(Color(NSColor.windowBackgroundColor))
            
            // 标签栏
            TabView(selection: $selectedTab) {
                ChatView()
                    .tabItem {
                        Image(systemName: "message.fill")
                        Text("对话")
                    }
                    .tag(0)
                
                HistoryView()
                    .tabItem {
                        Image(systemName: "clock.fill")
                        Text("历史")
                    }
                    .tag(1)
                
                AboutView()
                    .tabItem {
                        Image(systemName: "info.circle.fill")
                        Text("关于")
                    }
                    .tag(2)
            }
            .padding(.top, 1)
        }
        .frame(width: 400, height: 600)
    }
}

struct HistoryView: View {
    // 假设的历史记录
    @State private var historyItems: [HistoryItem] = [
        HistoryItem(id: UUID(), content: "什么是SwiftUI？", date: Date().addingTimeInterval(-86400)), // 昨天
        HistoryItem(id: UUID(), content: "Python与Swift的区别", date: Date().addingTimeInterval(-43200)), // 12小时前
        HistoryItem(id: UUID(), content: "如何使用Core Data", date: Date().addingTimeInterval(-3600)) // 1小时前
    ]
    
    var body: some View {
        List {
            ForEach(historyItems) { item in
                VStack(alignment: .leading) {
                    Text(item.content)
                        .font(.headline)
                        .lineLimit(1)
                    
                    Text(formattedDate(item.date))
                        .font(.caption)
                        .foregroundColor(.gray)
                }
                .padding(.vertical, 4)
            }
            .onDelete(perform: deleteItems)
        }
        .listStyle(PlainListStyle())
    }
    
    func deleteItems(at offsets: IndexSet) {
        historyItems.remove(atOffsets: offsets)
    }
    
    func formattedDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}

struct HistoryItem: Identifiable {
    let id: UUID
    let content: String
    let date: Date
}

struct AboutView: View {
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "text.quote")
                .font(.system(size: 60))
                .foregroundColor(.blue)
            
            Text("选中即问")
                .font(.largeTitle)
                .bold()
            
            Text("版本 1.0.0")
                .font(.subheadline)
            
            Text("一个智能的文本助手，选择文本后按下热键即可提问")
                .font(.body)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            
            Spacer()
            
            HStack {
                Link("Github", destination: URL(string: "https://github.com/yourusername/textcraft")!)
                Spacer()
                Link("反馈问题", destination: URL(string: "mailto:your.email@example.com")!)
                Spacer()
                Link("隐私政策", destination: URL(string: "https://example.com/privacy")!)
            }
            .padding()
        }
        .padding()
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
} 