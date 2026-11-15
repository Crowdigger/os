import SwiftUI

struct PieceDetailView: View {
    let record: PieceRecord
    let edit: () -> Void
    let duplicate: () -> Void
    let delete: () -> Void

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                Text("ORDEM DE SERVIÇO").font(.system(size: 12, weight: .semibold))
                    .tracking(1.3).foregroundStyle(Metro.blue)
                Text("OS: \(record.orderNumber)").font(.system(size: 32, weight: .light))
                if !record.client.isEmpty {
                    detailLine("CLIENTE", record.client)
                }
                detailLine("ONDE FOI GUARDADA", record.storageLocation)
                detailLine("DATA DO CADASTRO", record.createdAt.brazilianDateTime)

                Text("FOTOS DA PEÇA (\(record.photoNames.count))")
                    .font(.system(size: 13, weight: .bold)).foregroundStyle(Metro.blue)
                ForEach(record.photoNames, id: \.self) { name in
                    StoredPhotoView(name: name)
                }
                if let sheet = record.executionSheetName {
                    Text("FICHA DE EXECUÇÃO")
                        .font(.system(size: 13, weight: .bold)).foregroundStyle(Metro.orange)
                    StoredPhotoView(name: sheet)
                }
                HStack(spacing: 8) {
                    detailAction("DUPLICAR", "square.on.square", Metro.green, duplicate)
                    detailAction("EDITAR", "pencil", Metro.blue, edit)
                    detailAction("EXCLUIR", "trash", Metro.orange, delete)
                }
            }
            .padding(18)
        }
        .navigationTitle("Detalhes da OS")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func detailLine(_ heading: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(heading).font(.system(size: 12, weight: .semibold)).foregroundStyle(.secondary)
            Text(value).font(.system(size: 20, weight: .light))
        }
    }
    private func detailAction(_ title: String, _ icon: String, _ color: Color,
                              _ action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Label(title, systemImage: icon).font(.system(size: 10, weight: .semibold))
                .frame(maxWidth: .infinity, minHeight: 54)
                .foregroundStyle(.white).background(color)
        }
        .buttonStyle(.plain)
    }
}
