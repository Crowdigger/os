import SwiftUI
import UniformTypeIdentifiers

struct ContentView: View {
    @EnvironmentObject private var store: PieceStore
    @AppStorage("darkMode") private var darkMode = false
    @State private var search = ""
    @State private var route: [UUID] = []
    @State private var showNew = false
    @State private var editRecord: PieceRecord?
    @State private var deleteCandidate: PieceRecord?
    @AppStorage("lastManualBackup") private var lastManualBackup: Double = 0
    @State private var backupDocument: BackupDocument?
    @State private var exportBackup = false
    @State private var importBackup = false
    @State private var pendingRestore: Data?
    @State private var confirmRestore = false
    @State private var feedback: String?

    private var filtered: [PieceRecord] {
        let sorted = store.records.sorted { $0.createdAt > $1.createdAt }
        guard !search.isEmpty else { return sorted }
        return sorted.filter {
            $0.orderNumber.localizedCaseInsensitiveContains(search) ||
            $0.client.localizedCaseInsensitiveContains(search)
        }
    }

    var body: some View {
        NavigationStack(path: $route) {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    HStack(alignment: .center) {
                        Text("ARQUIVO DE PEÇAS")
                            .font(.system(size: 22, weight: .light))
                            .tracking(1.6)
                        Spacer()
                        Button { darkMode.toggle() } label: {
                            Image(systemName: darkMode ? "sun.max.fill" : "moon.fill")
                                .font(.system(size: 20)).foregroundStyle(Metro.blue)
                        }
                        .accessibilityLabel(darkMode ? "Ativar tema claro" : "Ativar tema escuro")
                        Menu {
                            Button {
                                do {
                                    backupDocument = BackupDocument(data: try store.makeBackup())
                                    exportBackup = true
                                } catch {
                                    feedback = "Não foi possível preparar o backup: \(error.localizedDescription)"
                                }
                            } label: {
                                Label("Salvar backup", systemImage: "square.and.arrow.up")
                            }
                            Button {
                                importBackup = true
                            } label: {
                                Label("Restaurar backup", systemImage: "square.and.arrow.down")
                            }
                            Divider()
                            Button(lastManualBackup == 0
                                   ? "Nenhum backup realizado"
                                   : "Último backup: \(Date(timeIntervalSince1970: lastManualBackup).brazilianDateTime)") {}
                                .disabled(true)
                        } label: {
                            Image(systemName: "ellipsis.circle")
                                .font(.system(size: 24))
                                .foregroundStyle(Metro.blue)
                                .frame(width: 44, height: 44)
                        }
                        .accessibilityLabel("Menu: backup e restauração")
                    }
                    HStack(spacing: 8) {
                        MetroTile(title: "NOVA PEÇA", symbol: "plus", color: Metro.blue) { showNew = true }
                        MetroTile(title: "OFFLINE", symbol: "checkmark", color: Metro.green) {}
                            .allowsHitTesting(false)
                    }
                    VStack(alignment: .leading, spacing: 10) {
                        Text("PESQUISAR ORDEM DE SERVIÇO")
                            .font(.system(size: 12, weight: .bold))
                            .tracking(1).foregroundStyle(Metro.blue)
                        HStack {
                            Image(systemName: "magnifyingglass").foregroundStyle(.secondary)
                            TextField("Número da OS ou cliente", text: $search)
                                .textInputAutocapitalization(.never)
                                .autocorrectionDisabled()
                        }
                        .padding(15)
                        .background(darkMode ? Metro.darkSurface : .white)
                        .clipShape(RoundedRectangle(cornerRadius: 3))
                    }
                    if filtered.isEmpty {
                        ContentUnavailableView("Nenhum cadastro encontrado", systemImage: "shippingbox",
                                               description: Text("Cadastre uma peça ou tente outra busca."))
                            .frame(maxWidth: .infinity)
                    }
                    ForEach(filtered) { record in
                        pieceCard(record)
                    }
                }
                .padding(18)
            }
            .background(darkMode ? Metro.darkBackground : Metro.lightBackground)
            .navigationBarHidden(true)
            .navigationDestination(for: UUID.self) { id in
                if let record = store.records.first(where: { $0.id == id }) {
                    PieceDetailView(record: record, edit: { editRecord = record },
                                    duplicate: { duplicate(record) }, delete: { deleteCandidate = record })
                } else {
                    ContentUnavailableView("Cadastro removido", systemImage: "shippingbox")
                }
            }
            .sheet(isPresented: $showNew) { PieceFormView(existing: nil) }
            .sheet(item: $editRecord) { PieceFormView(existing: $0) }
            .fileExporter(isPresented: $exportBackup, document: backupDocument,
                          contentType: .zip,
                          defaultFilename: "PecasOS-\(Date().formatted(.iso8601.year().month().day()))") { result in
                switch result {
                case .success:
                    lastManualBackup = Date().timeIntervalSince1970
                    feedback = "Backup salvo com sucesso no local escolhido."
                case .failure(let error): feedback = "Falha ao salvar o backup: \(error.localizedDescription)"
                }
                backupDocument = nil
            }
            .fileImporter(isPresented: $importBackup, allowedContentTypes: [.zip, .data],
                          allowsMultipleSelection: false) { result in
                do {
                    guard let url = try result.get().first else { return }
                    let access = url.startAccessingSecurityScopedResource()
                    defer { if access { url.stopAccessingSecurityScopedResource() } }
                    pendingRestore = try Data(contentsOf: url)
                    confirmRestore = true
                } catch {
                    feedback = "Não foi possível abrir o arquivo: \(error.localizedDescription)"
                }
            }
            .confirmationDialog("Restaurar backup?", isPresented: $confirmRestore,
                                titleVisibility: .visible) {
                Button("Substituir todos os cadastros", role: .destructive) {
                    guard let data = pendingRestore else { return }
                    do {
                        let count = try store.restoreBackup(data)
                        route.removeAll()
                        feedback = "Backup restaurado: \(count) cadastro(s)."
                    } catch { feedback = "Falha ao restaurar: \(error.localizedDescription)" }
                    pendingRestore = nil
                }
                Button("Cancelar", role: .cancel) { pendingRestore = nil }
            } message: {
                Text("A restauração substitui TODOS os cadastros e fotografias deste iPhone pelos do backup selecionado. Salve primeiro um backup dos dados atuais.")
            }
            .confirmationDialog("Excluir este cadastro?", isPresented: Binding(
                get: { deleteCandidate != nil }, set: { if !$0 { deleteCandidate = nil } }
            ), titleVisibility: .visible) {
                Button("Excluir permanentemente", role: .destructive) {
                    if let record = deleteCandidate {
                        do { try store.delete(record); route.removeAll() }
                        catch { feedback = error.localizedDescription }
                    }
                    deleteCandidate = nil
                }
            } message: { Text("A OS e suas fotos serão excluídas do aparelho.") }
            .alert("Peças OS", isPresented: Binding(
                get: { feedback != nil || store.lastError != nil },
                set: { if !$0 { feedback = nil; store.lastError = nil } }
            )) {
                Button("OK") { feedback = nil; store.lastError = nil }
            } message: { Text(feedback ?? store.lastError ?? "") }
        }
        .tint(Metro.blue)
        .preferredColorScheme(darkMode ? .dark : .light)
    }

    private func pieceCard(_ record: PieceRecord) -> some View {
        VStack(spacing: 0) {
            Button { route.append(record.id) } label: {
                HStack(alignment: .top, spacing: 13) {
                    if let first = record.photoNames.first, let image = store.image(first) {
                        Image(uiImage: image)
                            .resizable().scaledToFill()
                            .frame(width: 85, height: 87)
                            .clipped()
                    }
                    VStack(alignment: .leading, spacing: 5) {
                        Text("ORDEM DE SERVIÇO")
                            .font(.system(size: 10, weight: .semibold))
                            .tracking(1).foregroundStyle(Metro.blue)
                        Text("OS: \(record.orderNumber)")
                            .font(.system(size: 23, weight: .light))
                            .foregroundStyle(.primary)
                        if !record.client.isEmpty {
                            Text("CLIENTE: \(record.client)")
                                .font(.system(size: 13)).foregroundStyle(.primary)
                        }
                        Text("LOCAL: \(record.storageLocation)")
                            .font(.system(size: 13)).foregroundStyle(.secondary)
                        Text("CADASTRADA EM \(record.createdAt.brazilianDateTime)")
                            .font(.system(size: 11)).foregroundStyle(.secondary)
                        Text("\(record.photoNames.count) foto(s) · \(record.executionSheetName == nil ? "Sem ficha" : "Ficha anexada")")
                            .font(.system(size: 11)).foregroundStyle(.secondary)
                    }
                    Spacer(minLength: 0)
                }
                .padding(14)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .buttonStyle(.plain)
            Divider()
            HStack(spacing: 6) {
                action(symbol: "square.on.square", text: "DUPLICAR", color: Metro.green) { duplicate(record) }
                action(symbol: "trash", text: "EXCLUIR", color: Metro.orange) { deleteCandidate = record }
                action(symbol: "pencil", text: "EDITAR", color: Metro.blue) { editRecord = record }
            }
            .padding(10)
        }
        .background(darkMode ? Metro.darkSurface : .white)
        .clipShape(RoundedRectangle(cornerRadius: 3))
    }

    private func action(symbol: String, text: String, color: Color, perform: @escaping () -> Void) -> some View {
        Button(action: perform) {
            VStack(spacing: 4) {
                Image(systemName: symbol).font(.system(size: 20, weight: .regular))
                Text(text).font(.system(size: 10, weight: .semibold))
            }
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity, minHeight: 60)
            .background(color)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(text)
    }

    private func duplicate(_ record: PieceRecord) {
        do { try store.duplicate(record) }
        catch { feedback = "Não foi possível duplicar: \(error.localizedDescription)" }
    }
}


struct BackupDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.zip] }
    var data: Data

    init(data: Data) { self.data = data }
    init(configuration: ReadConfiguration) throws {
        guard let data = configuration.file.regularFileContents else {
            throw CocoaError(.fileReadCorruptFile)
        }
        self.data = data
    }
    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        FileWrapper(regularFileWithContents: data)
    }
}
