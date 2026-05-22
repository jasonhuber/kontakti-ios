import SwiftUI

struct AvatarView: View {
    let name: String
    var size: CGFloat = 40

    private var initials: String {
        let words = name.split(separator: " ").prefix(2)
        return words.compactMap { $0.first }.map { String($0).uppercased() }.joined()
    }

    private var font: Font {
        size < 32 ? .body : .title3
    }

    var body: some View {
        ZStack {
            Circle()
                .fill(Color(red: 0.31, green: 0.27, blue: 0.90))
            Text(initials)
                .font(font)
                .fontWeight(.bold)
                .foregroundColor(.white)
        }
        .frame(width: size, height: size)
    }
}

#Preview {
    HStack(spacing: 16) {
        AvatarView(name: "Jason Huber", size: 72)
        AvatarView(name: "Alice", size: 40)
        AvatarView(name: "Bob Smith", size: 28)
    }
    .padding()
}
