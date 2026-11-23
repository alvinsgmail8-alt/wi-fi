import SwiftUI

@main
struct TarjimonApp: App {
    var body: some Scene {
        WindowGroup { ContentView() }
    }
}

struct ContentView: View {
    @State private var test = ""

    var body: some View {
        NavigationStack {
            List {
                Section("1. Klaviaturani yoqing") {
                    Text("Sozlamalar → Umumiy → Klaviatura → Klaviaturalar → Yangi klaviatura qoʻshish → **Tarjimon**")
                    Text("Keyin roʻyxatda **Tarjimon** ni bosib, **«Toʻliq ruxsat»** (Allow Full Access) ni yoqing. Usiz tarjima internetga chiqa olmaydi.")
                    Button("Sozlamalarni ochish") {
                        if let url = URL(string: UIApplication.openSettingsURLString) {
                            UIApplication.shared.open(url)
                        }
                    }
                }

                Section("2. Bepul Gemini kalitini oling") {
                    Link("aistudio.google.com/apikey", destination: URL(string: "https://aistudio.google.com/apikey")!)
                    Text("Google hisobingiz bilan kiring → **Create API key** → kalitni nusxalang. Soʻng istalgan matn maydonida Tarjimon klaviaturasini oching, **⚙︎** → **«Kalitni saqlash»**.")
                }

                Section("3. Shu yerda sinab koʻring") {
                    TextField("Bosing, 🌐 bilan Tarjimon klaviaturasiga oʻting", text: $test, axis: .vertical)
                        .lineLimit(3...8)
                }

                Section("Qanday ishlatiladi") {
                    Label("Yuqoridan tilni tanlang (🇷🇺 Rus, 🇬🇧 Ingliz…)", systemImage: "globe")
                    Label("Oʻzbekcha yozing — matn klaviatura oynasida koʻrinadi", systemImage: "keyboard")
                    Label("«Tarjima» ni bosing — tarjima xabar maydoniga oʻzi tushadi", systemImage: "arrow.right.circle")
                    Label("Suhbatdosh yozganini tushunish uchun: xabarini nusxalang va 📋 → 🇺🇿 ni bosing", systemImage: "doc.on.clipboard")
                }
            }
            .navigationTitle("Tarjimon")
        }
    }
}
