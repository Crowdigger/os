import SwiftUI

enum Metro {
    static let blue = Color(red: 0, green: 120/255, blue: 215/255)
    static let orange = Color(red: 247/255, green: 133/255, blue: 31/255)
    static let green = Color(red: 16/255, green: 153/255, blue: 92/255)
    static let darkBackground = Color(red: 16/255, green: 22/255, blue: 31/255)
    static let darkSurface = Color(red: 32/255, green: 40/255, blue: 52/255)
    static let lightBackground = Color(red: 245/255, green: 248/255, blue: 251/255)
    static let ink = Color(red: 25/255, green: 41/255, blue: 59/255)
}

struct MetroTile: View {
    let title: String
    let symbol: String
    let color: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 14) {
                Image(systemName: symbol).font(.system(size: 28, weight: .light))
                Spacer(minLength: 0)
                Text(title).font(.system(size: 15, weight: .semibold)).tracking(0.8)
            }
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity, minHeight: 112, alignment: .leading)
            .padding(16)
            .background(color)
        }
        .buttonStyle(.plain)
    }
}

extension Date {
    var brazilianDateTime: String {
        formatted(Date.FormatStyle(date: .numeric, time: .shortened).locale(Locale(identifier: "pt_BR")))
    }
}
