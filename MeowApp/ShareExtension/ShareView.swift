#if canImport(UIKit)
import SwiftUI

struct ShareView: View {
    let viewModel: ShareViewModel
    let onDismiss: () -> Void

    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                contentPreview
                noteField
                statusArea
                Spacer()
            }
            .padding()
            .background(Color(hex: 0x0D0D0D))
            .navigationTitle("Send to Meow")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(Color(hex: 0x1A1A1A), for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { onDismiss() }
                        .foregroundStyle(.gray)
                }
                ToolbarItem(placement: .confirmationAction) {
                    sendButton
                }
            }
        }
        .preferredColorScheme(.dark)
    }

    // MARK: - Content Preview

    private var contentPreview: some View {
        HStack(spacing: 12) {
            Image(systemName: viewModel.contentIcon)
                .font(.title2)
                .foregroundStyle(Color(hex: 0x10A37F))
                .frame(width: 44, height: 44)
                .background(
                    Color(hex: 0x10A37F).opacity(0.15)
                )
                .clipShape(RoundedRectangle(cornerRadius: 10))

            VStack(alignment: .leading, spacing: 4) {
                Text("Sharing with Meow")
                    .font(.caption)
                    .foregroundStyle(Color(hex: 0x8E8E8E))
                Text(viewModel.contentPreviewText)
                    .font(.subheadline)
                    .foregroundStyle(Color(hex: 0xECECEC))
                    .lineLimit(2)
            }

            Spacer()
        }
        .padding(12)
        .background(Color(hex: 0x1A1A1A))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    // MARK: - Note Field

    private var noteField: some View {
        TextField("Add a note...", text: Binding(
            get: { viewModel.note },
            set: { viewModel.note = $0 }
        ), axis: .vertical)
            .lineLimit(2...5)
            .textFieldStyle(.plain)
            .padding(12)
            .foregroundStyle(Color(hex: 0xECECEC))
            .background(Color(hex: 0x1A1A1A))
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color.white.opacity(0.08), lineWidth: 1)
            )
    }

    // MARK: - Status

    @ViewBuilder
    private var statusArea: some View {
        if viewModel.isSending {
            HStack(spacing: 8) {
                ProgressView()
                    .tint(Color(hex: 0x10A37F))
                Text("Sending to meow...")
                    .font(.caption)
                    .foregroundStyle(Color(hex: 0x8E8E8E))
            }
        }
        if let error = viewModel.errorMessage {
            Text(error)
                .font(.caption)
                .foregroundStyle(Color(hex: 0xEF4444))
        }
    }

    // MARK: - Send Button

    private var sendButton: some View {
        Button {
            Task {
                await viewModel.send()
                if viewModel.isDone { onDismiss() }
            }
        } label: {
            HStack(spacing: 4) {
                Image(systemName: "paperplane.fill")
                Text("Send")
            }
            .foregroundStyle(Color(hex: 0x10A37F))
        }
        .disabled(
            viewModel.isSending || viewModel.extractedContent.isEmpty
        )
    }
}
#endif
