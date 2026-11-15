import SwiftUI
import UIKit

struct PieceFormView: View {
    @EnvironmentObject private var store: PieceStore
    @Environment(\.dismiss) private var dismiss
    let existing: PieceRecord?

    @State private var step = 0
    @State private var orderNumber: String
    @State private var client: String
    @State private var storageLocation: String
    @State private var photos: [String]
    @State private var executionSheet: String?
    @State private var createdNames: [String] = []
    @State private var photoKind: PhotoKind = .piece
    @State private var errorText: String?
    @State private var didSave = false

    enum PhotoKind { case piece, sheet }

    init(existing: PieceRecord?) {
        self.existing = existing
        _orderNumber = State(initialValue: existing?.orderNumber ?? "")
        _client = State(initialValue: existing?.client ?? "")
        _storageLocation = State(initialValue: existing?.storageLocation ?? "")
        _photos = State(initialValue: existing?.photoNames ?? [])
        _executionSheet = State(initialValue: existing?.executionSheetName)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    Text("ETAPA \(step + 1) DE 4")
                        .font(.system(size: 12, weight: .bold)).tracking(1.3).foregroundStyle(Metro.blue)
                    HStack(spacing: 5) {
                        ForEach(0..<4, id: \.self) { i in
                            Rectangle().fill(i <= step ? Metro.blue : Color.gray.opacity(0.25))
                                .frame(height: 5)
                        }
                    }
                    switch step {
                    case 0: orderStep
                    case 1: locationStep
                    case 2: photosStep
                    default: executionSheetStep
                    }
                    Button { advance() } label: {
                        Text(step == 3 ? "SALVAR CADASTRO" : "CONTINUAR")
                            .font(.system(size: 15, weight: .semibold))
                            .frame(maxWidth: .infinity, minHeight: 52)
                            .foregroundStyle(.white)
                            .background(step == 3 ? Metro.green : Metro.blue)
                    }
                    .buttonStyle(.plain)
                    Button { goBack() } label: {
                        Text(step == 0 ? "CANCELAR" : "VOLTAR")
                            .frame(maxWidth: .infinity, minHeight: 46)
                    }
                }
                .padding(18)
            }
            .navigationTitle(existing == nil ? "Nova peça" : "Editar peça")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button(step == 0 ? "Fechar" : "Voltar") { goBack() }
                }
            }
            .interactiveDismissDisabled()
            .sheet(item: photoSourceBinding) { source in
                PhotoPicker(source: source.source, onImage: { image in
                    activePicker = nil
                    do {
                        let name = try store.savePhoto(image, isExecutionSheet: photoKind == .sheet)
                        createdNames.append(name)
                        if photoKind == .piece {
                            if photos.count < 5 { photos.append(name) }
                        } else { executionSheet = name }
                    } catch { errorText = error.localizedDescription }
                }, onCancel: { activePicker = nil })
                .ignoresSafeArea()
            }
            .alert("Peças OS", isPresented: Binding(
                get: { errorText != nil }, set: { if !$0 { errorText = nil } }
            )) { Button("OK") { errorText = nil } }
              message: { Text(errorText ?? "") }
            .onDisappear {
                if !didSave { store.removeUnreferenced(createdNames) }
            }
        }
    }

    // A compact wrapper gives the sheet a stable Identifiable presentation value.
    private struct SourceChoice: Identifiable {
        let id: UUID = UUID()
        let source: PhotoPicker.Source
    }
    @State private var activePicker: SourceChoice?
    private var photoSourceBinding: Binding<SourceChoice?> { $activePicker }

    private var orderStep: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionTitle("1. Número da ordem de serviço")
            Text("Digite o número exatamente como aparece na OS.").foregroundStyle(.secondary)
            TextField("Ex.: 2026-00125", text: $orderNumber)
                .textInputAutocapitalization(.characters)
                .textFieldStyle(.roundedBorder)
            sectionTitle("Nome do cliente")
            TextField("Nome do cliente", text: $client).textFieldStyle(.roundedBorder)
        }
    }
    private var locationStep: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionTitle("2. Onde a peça foi guardada?")
            Text("Ex.: Almoxarifado, estante B, prateleira 3.").foregroundStyle(.secondary)
            TextField("Local / posição", text: $storageLocation).textFieldStyle(.roundedBorder)
        }
    }
    private var photosStep: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionTitle("3. Fotos da peça")
            Text("Obrigatório: 1 a 5 fotos. As novas fotos são comprimidas automaticamente.")
                .foregroundStyle(.secondary)
            Text("\(photos.count) DE 5 FOTOS").font(.system(size: 13, weight: .bold)).foregroundStyle(Metro.blue)
            ForEach(photos, id: \.self) { name in
                VStack(spacing: 6) {
                    StoredPhotoView(name: name)
                    Button("Remover foto", role: .destructive) { photos.removeAll(where: { $0 == name }) }
                }
            }
            if photos.count < 5 { photoButtons(kind: .piece) }
        }
    }
    private var executionSheetStep: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionTitle("4. Ficha de execução")
            Text("Foto opcional da ficha com as informações da peça e o número da OS.")
                .foregroundStyle(.secondary)
            if let executionSheet {
                StoredPhotoView(name: executionSheet)
                Button("Remover ficha", role: .destructive) { self.executionSheet = nil }
            }
            photoButtons(kind: .sheet)
        }
    }
    private func sectionTitle(_ title: String) -> some View {
        Text(title).font(.system(size: 23, weight: .light))
    }
    private func photoButtons(kind: PhotoKind) -> some View {
        VStack(spacing: 10) {
            Button {
                photoKind = kind
                if UIImagePickerController.isSourceTypeAvailable(.camera) {
                    activePicker = SourceChoice(source: .camera)
                } else { errorText = "Câmera indisponível neste dispositivo." }
            } label: {
                Label("Tirar foto", systemImage: "camera.fill")
                    .frame(maxWidth: .infinity, minHeight: 49)
                    .foregroundStyle(.white).background(Metro.blue)
            }
            .buttonStyle(.plain)
            Button {
                photoKind = kind
                activePicker = SourceChoice(source: .library)
            } label: {
                Label("Escolher da galeria", systemImage: "photo.on.rectangle")
                    .frame(maxWidth: .infinity, minHeight: 49)
                    .foregroundStyle(.white).background(Metro.orange)
            }
            .buttonStyle(.plain)
        }
    }
    private func advance() {
        switch step {
        case 0:
            guard !orderNumber.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                errorText = "Informe o número da ordem de serviço."; return
            }
        case 1:
            guard !storageLocation.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                errorText = "Informe onde a peça foi guardada."; return
            }
        case 2:
            guard (1...5).contains(photos.count) else {
                errorText = "É necessário incluir de uma a cinco fotos da peça."; return
            }
        default: break
        }
        if step < 3 { step += 1; return }
        let record = PieceRecord(id: existing?.id ?? UUID(),
                                 orderNumber: orderNumber.trimmingCharacters(in: .whitespacesAndNewlines),
                                 client: client.trimmingCharacters(in: .whitespacesAndNewlines),
                                 storageLocation: storageLocation.trimmingCharacters(in: .whitespacesAndNewlines),
                                 photoNames: photos, executionSheetName: executionSheet,
                                 createdAt: existing?.createdAt ?? Date())
        do {
            try store.save(record)
            didSave = true
            store.removeUnreferenced(createdNames)
            dismiss()
        } catch { errorText = "Falha ao salvar: \(error.localizedDescription)" }
    }
    private func goBack() {
        if step > 0 { step -= 1 }
        else { dismiss() }
    }
}
