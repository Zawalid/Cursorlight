import BeaconCore
import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var model: AppModel
    @State var page: SettingsPage
    /// False only for offscreen snapshots, where ScrollView does not render.
    var scrolls = true

    var body: some View {
        HStack(spacing: 0) {
            sidebar
            Rectangle().fill(Theme.line).frame(width: 1)
            pageContainer {
                Group {
                    switch page {
                    case .highlight: HighlightPage()
                    case .ink: InkPage()
                    case .triggers: TriggersPage()
                    case .profiles: ProfilesPage()
                    case .displays: DisplaysPage()
                    case .about: AboutPage()
                    }
                }
                .padding(.horizontal, 32).padding(.top, 38).padding(.bottom, 32)
                .frame(maxWidth: .infinity, alignment: .topLeading)
                .id(page)
                .transition(.opacity)
            }
        }
        .frame(minWidth: 860, minHeight: 600)
        .background(Theme.window)
        .preferredColorScheme(.dark)
    }

    @ViewBuilder
    private func pageContainer<Content: View>(@ViewBuilder _ content: () -> Content) -> some View {
        if scrolls {
            ScrollView { content() }
        } else {
            content().frame(maxHeight: .infinity, alignment: .top)
        }
    }

    private var sidebar: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: 10) {
                BrandMark().frame(width: 26, height: 26)
                Text(Branding.appName).font(.system(size: 14, weight: .semibold)).foregroundStyle(Theme.text)
            }
            .padding(.horizontal, 10).padding(.top, 34).padding(.bottom, 18)
            ForEach(SettingsPage.allCases.filter { $0 != .about }) { item in navButton(item) }
            Spacer()
            navButton(.about)
            ShareNote().padding(.top, 8)
        }
        .padding(10)
        .frame(width: 210)
        .background(Theme.sidebar)
    }

    private func navButton(_ item: SettingsPage) -> some View {
        Button {
            withAnimation(.easeOut(duration: 0.18)) { page = item }
        } label: {
            HStack(spacing: 10) {
                Image(systemName: item.symbol).font(.system(size: 13)).frame(width: 18)
                Text(item.title).font(.system(size: 13))
                Spacer()
            }
            .foregroundStyle(page == item ? Theme.text : Theme.dim)
            .padding(.horizontal, 10).padding(.vertical, 8)
            .background(page == item ? Color.white.opacity(0.08) : .clear, in: RoundedRectangle(cornerRadius: 9, style: .continuous))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(page == item ? .isSelected : [])
    }
}

/// The product mark: a bright core inside a glowing ring, in the accent color.
struct BrandMark: View {
    var body: some View {
        RoundedRectangle(cornerRadius: 8, style: .continuous)
            .fill(Color(red: 0.16, green: 0.08, blue: 0.06))
            .overlay(
                Circle().fill(RadialGradient(colors: [.white, Theme.accent, Theme.accent.opacity(0)], center: .center, startRadius: 0, endRadius: 13))
            )
            .overlay(RoundedRectangle(cornerRadius: 8, style: .continuous).stroke(Color.white.opacity(0.1)))
    }
}

/// Plain reminder about full-screen versus window share. Detection arrives later; this does not claim any.
struct ShareNote: View {
    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: "rectangle.on.rectangle").font(.system(size: 11)).foregroundStyle(Theme.dim).padding(.top, 1)
            Text("Share the whole screen so viewers can see effects.")
                .font(.system(size: 11)).foregroundStyle(Theme.dim).fixedSize(horizontal: false, vertical: true)
        }
        .padding(10)
        .background(Color.white.opacity(0.04), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
    }
}
