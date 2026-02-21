import SwiftUI

struct CollectionsView: View {
    @EnvironmentObject private var vm: AppViewModel
    @State private var showNewCollectionSheet = false
    @State private var newCollectionName = ""
    @State private var newCollectionDescription = ""
    @State private var showShareSheet = false
    @State private var selectedCollection: NameCollection?

    var body: some View {
        NavigationStack {
            ZStack {
                LinearGradient(
                    colors: [Color.black.opacity(0.22), Color.blue.opacity(0.22)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 32) {
                        // Header
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Collections")
                                .font(.system(size: 32, weight: .bold, design: .default))
                                .foregroundColor(.primary)
                            Text("Create and share name collections")
                                .font(.body)
                                .foregroundStyle(.secondary)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(16)

                        // New Collection Button
                        Button(action: { showNewCollectionSheet = true }) {
                            HStack(spacing: 8) {
                                Image(systemName: "plus.circle.fill")
                                    .font(.system(size: 18, weight: .semibold))
                                Text("New Collection")
                                    .font(.system(size: 16, weight: .semibold))
                            }
                            .frame(maxWidth: .infinity)
                            .padding(16)
                            .background(Color.blue)
                            .foregroundColor(.white)
                            .cornerRadius(12)
                        }
                        .padding(.horizontal, 16)
                        .accessibilityLabel("Create a new collection")

                        // Collections List
                        if vm.collections.isEmpty {
                            VStack(spacing: 12) {
                                Image(systemName: "folder.badge.plus")
                                    .font(.system(size: 48))
                                    .foregroundStyle(.secondary)
                                Text("No collections yet")
                                    .font(.headline)
                                Text("Create your first collection to organize names")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .multilineTextAlignment(.center)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(32)
                        } else {
                            VStack(spacing: 12) {
                                ForEach(vm.collections) { collection in
                                    CollectionCard(
                                        collection: collection,
                                        onSelect: {
                                            vm.loadCollection(collection)
                                        },
                                        onShare: {
                                            selectedCollection = collection
                                            vm.shareCollection(collection)
                                            showShareSheet = true
                                        },
                                        onDelete: {
                                            vm.deleteCollection(collection)
                                        }
                                    )
                                }
                            }
                            .padding(.horizontal, 16)
                        }

                        Spacer()
                    }
                    .padding(.vertical, 16)
                }
            }
            .navigationTitle("Collections")
            .sheet(isPresented: $showNewCollectionSheet) {
                NewCollectionSheet(
                    name: $newCollectionName,
                    description: $newCollectionDescription,
                    onSave: {
                        vm.createCollection(
                            name: newCollectionName,
                            description: newCollectionDescription
                        )
                        newCollectionName = ""
                        newCollectionDescription = ""
                        showNewCollectionSheet = false
                    },
                    onCancel: {
                        showNewCollectionSheet = false
                    }
                )
            }
            .sheet(isPresented: $showShareSheet) {
                if let url = vm.shareUrl {
                    ShareSheet(url: url)
                }
            }
        }
    }
}

struct CollectionCard: View {
    let collection: NameCollection
    let onSelect: () -> Void
    let onShare: () -> Void
    let onDelete: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(collection.name)
                        .font(.headline)
                        .foregroundColor(.primary)
                        .lineLimit(2)
                    if let description = collection.description {
                        Text(description)
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .lineLimit(2)
                    }
                }
                Spacer(minLength: 8)
                VStack(alignment: .trailing, spacing: 2) {
                    Text("\(collection.entries.count)")
                        .font(.headline)
                        .foregroundColor(.blue)
                    Text(collection.entries.count == 1 ? "name" : "names")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }

            Divider()
                .padding(.vertical, 4)

            HStack(spacing: 8) {
                Button(action: onSelect) {
                    Label("Load", systemImage: "arrow.down.doc")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .frame(maxWidth: .infinity)
                        .padding(10)
                        .background(Color.blue.opacity(0.15))
                        .foregroundColor(.blue)
                        .cornerRadius(8)
                        .contentShape(Rectangle())
                }
                .accessibilityLabel("Load collection \(collection.name)")

                Button(action: onShare) {
                    Label("Share", systemImage: "square.and.arrow.up")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .frame(maxWidth: .infinity)
                        .padding(10)
                        .background(Color.green.opacity(0.15))
                        .foregroundColor(.green)
                        .cornerRadius(8)
                        .contentShape(Rectangle())
                }
                .accessibilityLabel("Share collection \(collection.name)")

                Button(role: .destructive, action: onDelete) {
                    Label("Delete", systemImage: "trash")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .frame(maxWidth: .infinity)
                        .padding(10)
                        .background(Color.red.opacity(0.15))
                        .foregroundColor(.red)
                        .cornerRadius(8)
                        .contentShape(Rectangle())
                }
                .accessibilityLabel("Delete collection \(collection.name)")
            }
        }
        .padding(16)
        .background(Color.white.opacity(0.95))
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.05), radius: 4, x: 0, y: 2)
    }
}

struct NewCollectionSheet: View {
    @Binding var name: String
    @Binding var description: String
    let onSave: () -> Void
    let onCancel: () -> Void

    var isValid: Bool {
        !name.trimmingCharacters(in: .whitespaces).isEmpty
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                Form {
                    Section("Collection Details") {
                        TextField("Collection Name", text: $name)
                            .accessibilityLabel("Collection name")
                            .accessibilityHint("Enter the name for your collection")
                        TextField("Description (optional)", text: $description)
                            .accessibilityLabel("Collection description")
                            .accessibilityHint("Enter an optional description")
                    }
                }

                VStack(spacing: 12) {
                    Button(action: onSave) {
                        Text("Save Collection")
                            .font(.system(size: 16, weight: .semibold))
                            .frame(maxWidth: .infinity)
                            .padding(16)
                            .background(isValid ? Color.blue : Color.gray)
                            .foregroundColor(.white)
                            .cornerRadius(12)
                    }
                    .disabled(!isValid)

                    Button(action: onCancel) {
                        Text("Cancel")
                            .font(.system(size: 16, weight: .semibold))
                            .frame(maxWidth: .infinity)
                            .padding(16)
                            .background(Color.gray.opacity(0.1))
                            .foregroundColor(.primary)
                            .cornerRadius(12)
                    }
                }
                .padding(16)
            }
            .navigationTitle("New Collection")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}

struct ShareSheet: View {
    let url: URL
    @State private var copied = false
    @Environment(\.dismiss) var dismiss

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                VStack(spacing: 16) {
                    Text("Share Collection")
                        .font(.system(size: 24, weight: .bold))
                        .frame(maxWidth: .infinity, alignment: .leading)

                    Text("Share this URL with others to let them import this collection:")
                        .font(.body)
                        .foregroundColor(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }

                VStack(spacing: 12) {
                    Text(url.absoluteString)
                        .font(.system(.caption, design: .monospaced))
                        .lineLimit(4)
                        .padding(16)
                        .background(Color.gray.opacity(0.1))
                        .cornerRadius(12)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }

                VStack(spacing: 12) {
                    Button(action: {
                        UIPasteboard.general.string = url.absoluteString
                        copied = true
                        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                            copied = false
                        }
                    }) {
                        HStack(spacing: 8) {
                            Image(systemName: copied ? "checkmark.circle.fill" : "doc.on.doc")
                                .font(.system(size: 18, weight: .semibold))
                            Text(copied ? "Copied!" : "Copy URL")
                                .font(.system(size: 16, weight: .semibold))
                        }
                        .frame(maxWidth: .infinity)
                        .padding(16)
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(12)
                    }
                    .accessibilityLabel(copied ? "URL copied to clipboard" : "Copy URL to clipboard")

                    Button(action: { dismiss() }) {
                        Text("Done")
                            .font(.system(size: 16, weight: .semibold))
                            .frame(maxWidth: .infinity)
                            .padding(16)
                            .background(Color.gray.opacity(0.1))
                            .foregroundColor(.primary)
                            .cornerRadius(12)
                    }
                }

                Spacer()
            }
            .padding(16)
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}

