import SwiftUI

/// What the cache is holding, and a way to be rid of it.
///
/// The cache has existed since the first version with no way for a reader to see its size or
/// clear it, which made it the one part of the app that only grew.
struct StorageView: View {
    let language: Language
    let cacheRepository: CacheRepository

    @State private var sizeInBytes: Int = 0

    var body: some View {
        VStack(alignment: .leading, spacing: Tokens.Space.l) {
            Text(L10n.storageCached(language, formattedSize))
                .font(Tokens.Typography.category)
                .foregroundStyle(Tokens.Palette.ink)

            Text(L10n.storageExplain(language))
                .font(Tokens.Typography.summary)
                .foregroundStyle(Tokens.Palette.inkSecondary)
                .fixedSize(horizontal: false, vertical: true)

            Button(L10n.storageClear(language)) {
                try? cacheRepository.clearAll()
                sizeInBytes = cacheRepository.totalSizeInBytes()
            }
            .font(Tokens.Typography.category.weight(.semibold))
            .foregroundStyle(Tokens.Palette.accent)
            .frame(minHeight: 44)

            Spacer()
        }
        .padding(Tokens.Space.l)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Tokens.Palette.background)
        .navigationTitle(L10n.settingsSectionStorage(language))
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { sizeInBytes = cacheRepository.totalSizeInBytes() }
    }

    private var formattedSize: String {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        return formatter.string(fromByteCount: Int64(sizeInBytes))
    }
}
