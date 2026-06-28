//
//  AppIconSettingsView.swift
//  Clarity
//
//  Created by Craig Peters on 09/05/2026.
//


import SwiftData
import SwiftUI
import UniformTypeIdentifiers
import StoreKit

struct AppIconSettingsView: View {
    struct AppIcon: Identifiable, Hashable {
        let id: String
        let displayName: String
        let previewImageName: String
        var requiresPremium: Bool = false
        // id should match the alternate icon name in Info.plist (CFBundleAlternateIcons). Use "primary" for the default icon.
    }

    // Update this list to match the icons you have configured in your asset catalog and Info.plist.
    private let freeIcons: [AppIcon] = [
        .init(id: "Default", displayName: "Default", previewImageName: "Appicon-Preview-Default"),
        .init(id: "Pride", displayName: "Pride", previewImageName: "Appicon-Preview-Pride"),
        .init(id: "Autumn", displayName: "Autumn", previewImageName: "Appicon-Preview-Autumn"),
        .init(id: "Christmas", displayName: "Christmas", previewImageName: "Appicon-Preview-Christmas"),
        .init(id: "Valentines", displayName: "Valentines", previewImageName: "Appicon-Preview-Valentines"),
        .init(id: "NewYear", displayName: "Chinese New Year", previewImageName: "Appicon-Preview-NewYear"),
        .init(id: "Easter", displayName: "Easter", previewImageName: "Appicon-Preview-Easter")
    ]

    private let premiumIcons: [AppIcon] = [
        .init(id: "Premium", displayName: "Premium", previewImageName: "Appicon-Preview-Premium", requiresPremium: true)
    ]

    @Environment(Store.self) private var store
    @State private var currentIconName: String = "primary"
    @State private var isChanging = false
    @State private var errorMessage: String?
    @State private var showingStore = false

    var body: some View {
        List {
            Section(footer: footerText) {
                ForEach(freeIcons) { icon in
                    iconRow(icon)
                        .onTapGesture { select(icon: icon) }
                }
            }

            Section(header: Text("Premium"), footer: Text("Requires Clarity Premium.")) {
                ForEach(premiumIcons) { icon in
                    iconRow(icon)
                        .onTapGesture {
                            if store.hasBoughtPremium {
                                select(icon: icon)
                            } else {
                                showingStore = true
                            }
                        }
                }
            }
        }
        .navigationTitle("App Icon")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear(perform: loadCurrentIcon)
        .alert("Couldn't Change Icon", isPresented: .constant(errorMessage != nil)) {
            Button("OK") { errorMessage = nil }
        } message: {
            if let errorMessage { Text(errorMessage) }
        }
        .onChange(of: store.hasBoughtPremium) { _, hasPremium in
            if !hasPremium {
                revertToDefaultIfNeeded()
            }
        }
        .sheet(isPresented: $showingStore) {
            NavigationStack {
                PremiumSettings()
                    .navigationTitle("Clarity Premium")
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) {
                            Button("Done") { showingStore = false }
                        }
                    }
            }
        }
    }

    @ViewBuilder
    private func iconRow(_ icon: AppIcon) -> some View {
        let isSelected = currentIconName == icon.id || (currentIconName == "primary" && icon.id == "Default")
        let isLocked = icon.requiresPremium && !store.hasBoughtPremium

        HStack(spacing: 16) {
            ZStack(alignment: .bottomTrailing) {
                Image(icon.previewImageName)
                    .resizable()
                    .aspectRatio(1, contentMode: .fit)
                    .frame(width: 48, height: 48)
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .stroke(Color.secondary.opacity(0.2), lineWidth: 1)
                    )
                    .opacity(isLocked ? 0.5 : 1)

                if isLocked {
                    Image(systemName: "lock.fill")
                        .font(.caption2)
                        .foregroundStyle(.white)
                        .padding(3)
                        .background(Color.secondary, in: Circle())
                        .offset(x: 4, y: 4)
                }
            }

            VStack(alignment: .leading) {
                Text(icon.displayName)
                if isSelected {
                    Text("Selected").font(.caption).foregroundStyle(.secondary)
                } else if isLocked {
                    Text("Premium required").font(.caption).foregroundStyle(.secondary)
                }
            }

            Spacer()

            if isSelected {
                Image(systemName: "checkmark").foregroundColor(.accentColor)
            }
        }
        .contentShape(Rectangle())
    }

    private var footerText: some View {
        Group {
            #if os(iOS)
            if !UIApplication.shared.supportsAlternateIcons {
                Text("This device does not support alternate app icons.")
            } else {
                Text("Choose a preferred app icon. You can change this anytime.")
            }
            #else
            Text("App icon selection is only available on iOS.")
            #endif
        }
        .font(.footnote)
        .foregroundStyle(.secondary)
    }

    private func loadCurrentIcon() {
        #if os(iOS)
        if let name = UIApplication.shared.alternateIconName {
            currentIconName = name
        } else {
            currentIconName = "primary"
        }
        #else
        currentIconName = "primary"
        #endif
    }

    private func revertToDefaultIfNeeded() {
        let premiumIconIDs = Set(premiumIcons.map(\.id))
        guard premiumIconIDs.contains(currentIconName) else { return }
        #if os(iOS)
        UIApplication.shared.setAlternateIconName(nil) { error in
            DispatchQueue.main.async {
                if error == nil {
                    currentIconName = "Default"
                }
            }
        }
        #endif
    }

    private func select(icon: AppIcon) {
        guard !isChanging else { return }
        #if os(iOS)
        guard UIApplication.shared.supportsAlternateIcons else { return }
        isChanging = true
        let targetName: String? = (icon.id == "primary") ? nil : icon.id
        UIApplication.shared.setAlternateIconName(targetName) { error in
            DispatchQueue.main.async {
                isChanging = false
                if let error = error {
                    errorMessage = error.localizedDescription
                } else {
                    currentIconName = icon.id
                }
            }
        }
        #else
        // No-op on non-iOS platforms
        #endif
    }
}
