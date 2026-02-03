import SwiftUI

/// Renders markdown content as styled SwiftUI views.
/// Supports: headers, bold, italic, bold-italic, inline code,
/// code blocks, lists, horizontal rules, and links.
struct MarkdownText: View {
    let content: String
    var textColor: Color = .primary

    var body: some View {
        VStack(alignment: .leading, spacing: MeowTheme.spacingSM) {
            ForEach(Array(parseBlocks().enumerated()), id: \.offset) { _, block in
                renderBlock(block)
            }
        }
    }
}

// MARK: - Block Types

private enum MarkdownBlock {
    case heading(level: Int, text: String)
    case paragraph(text: String)
    case bulletItem(text: String)
    case numberedItem(number: String, text: String)
    case codeBlock(code: String)
    case horizontalRule
}

// MARK: - Parsing

extension MarkdownText {
    private func parseBlocks() -> [MarkdownBlock] {
        var blocks: [MarkdownBlock] = []
        let lines = content.components(separatedBy: "\n")
        var i = 0
        var paragraphBuffer: [String] = []

        func flushParagraph() {
            let text = paragraphBuffer.joined(separator: "\n").trimmingCharacters(in: .whitespaces)
            if !text.isEmpty {
                blocks.append(.paragraph(text: text))
            }
            paragraphBuffer.removeAll()
        }

        while i < lines.count {
            let line = lines[i]
            let trimmed = line.trimmingCharacters(in: .whitespaces)

            // Code block (```)
            if trimmed.hasPrefix("```") {
                flushParagraph()
                var codeLines: [String] = []
                i += 1
                while i < lines.count {
                    if lines[i].trimmingCharacters(in: .whitespaces).hasPrefix("```") {
                        i += 1
                        break
                    }
                    codeLines.append(lines[i])
                    i += 1
                }
                blocks.append(.codeBlock(code: codeLines.joined(separator: "\n")))
                continue
            }

            // Horizontal rule
            if trimmed == "---" || trimmed == "***" || trimmed == "___" {
                flushParagraph()
                blocks.append(.horizontalRule)
                i += 1
                continue
            }

            // Headings
            if let heading = parseHeading(trimmed) {
                flushParagraph()
                blocks.append(heading)
                i += 1
                continue
            }

            // Bullet list
            if trimmed.hasPrefix("- ") || trimmed.hasPrefix("* ") || trimmed.hasPrefix("+ ") {
                flushParagraph()
                let text = String(trimmed.dropFirst(2))
                blocks.append(.bulletItem(text: text))
                i += 1
                continue
            }

            // Numbered list
            if let match = trimmed.firstMatch(of: /^(\d+)\.\s+(.+)$/) {
                flushParagraph()
                blocks.append(.numberedItem(number: String(match.1), text: String(match.2)))
                i += 1
                continue
            }

            // Empty line = paragraph break
            if trimmed.isEmpty {
                flushParagraph()
                i += 1
                continue
            }

            // Regular text
            paragraphBuffer.append(line)
            i += 1
        }

        flushParagraph()
        return blocks
    }

    private func parseHeading(_ line: String) -> MarkdownBlock? {
        if line.hasPrefix("### ") {
            return .heading(level: 3, text: String(line.dropFirst(4)))
        } else if line.hasPrefix("## ") {
            return .heading(level: 2, text: String(line.dropFirst(3)))
        } else if line.hasPrefix("# ") {
            return .heading(level: 1, text: String(line.dropFirst(2)))
        }
        return nil
    }
}

// MARK: - Rendering

extension MarkdownText {
    @ViewBuilder
    private func renderBlock(_ block: MarkdownBlock) -> some View {
        switch block {
        case .heading(let level, let text):
            styledInlineText(text)
                .font(headingFont(level))
                .foregroundColor(textColor)

        case .paragraph(let text):
            styledInlineText(text)
                .font(MeowTheme.body)
                .foregroundColor(textColor)

        case .bulletItem(let text):
            HStack(alignment: .top, spacing: MeowTheme.spacingSM) {
                Text("\u{2022}")
                    .font(MeowTheme.body)
                    .foregroundColor(textColor.opacity(0.6))
                styledInlineText(text)
                    .font(MeowTheme.body)
                    .foregroundColor(textColor)
            }

        case .numberedItem(let number, let text):
            HStack(alignment: .top, spacing: MeowTheme.spacingSM) {
                Text("\(number).")
                    .font(MeowTheme.body)
                    .foregroundColor(textColor.opacity(0.6))
                styledInlineText(text)
                    .font(MeowTheme.body)
                    .foregroundColor(textColor)
            }

        case .codeBlock(let code):
            Text(code)
                .font(MeowTheme.mono)
                .foregroundColor(MeowTheme.accent)
                .padding(MeowTheme.spacingSM)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(textColor.opacity(0.06))
                .clipShape(RoundedRectangle(cornerRadius: MeowTheme.cornerSM))

        case .horizontalRule:
            Rectangle()
                .fill(textColor.opacity(0.15))
                .frame(height: 1)
                .padding(.vertical, MeowTheme.spacingXS)
        }
    }

    private func headingFont(_ level: Int) -> Font {
        switch level {
        case 1: .system(.title2, weight: .bold)
        case 2: .system(.title3, weight: .semibold)
        default: .system(.headline, weight: .semibold)
        }
    }

    /// Renders inline markdown: **bold**, *italic*, ***bold-italic***, `code`
    private func styledInlineText(_ text: String) -> Text {
        var result = Text("")
        var remaining = text[text.startIndex...]

        while !remaining.isEmpty {
            // Inline code: `text`
            if remaining.hasPrefix("`"),
               let endIdx = remaining.dropFirst().firstIndex(of: "`") {
                let code = remaining[remaining.index(after: remaining.startIndex)..<endIdx]
                result = result + Text(String(code))
                    .font(MeowTheme.mono)
                    .foregroundColor(MeowTheme.accent)
                remaining = remaining[remaining.index(after: endIdx)...]
                continue
            }

            // Bold-italic: ***text***
            if remaining.hasPrefix("***"),
               let range = remaining.range(of: "***", range: remaining.index(remaining.startIndex, offsetBy: 3)..<remaining.endIndex) {
                let inner = remaining[remaining.index(remaining.startIndex, offsetBy: 3)..<range.lowerBound]
                result = result + Text(String(inner)).bold().italic()
                remaining = remaining[range.upperBound...]
                continue
            }

            // Bold: **text**
            if remaining.hasPrefix("**"),
               let range = remaining.range(of: "**", range: remaining.index(remaining.startIndex, offsetBy: 2)..<remaining.endIndex) {
                let inner = remaining[remaining.index(remaining.startIndex, offsetBy: 2)..<range.lowerBound]
                result = result + Text(String(inner)).bold()
                remaining = remaining[range.upperBound...]
                continue
            }

            // Italic: *text*
            if remaining.hasPrefix("*"),
               let endIdx = remaining.dropFirst().firstIndex(of: "*") {
                let inner = remaining[remaining.index(after: remaining.startIndex)..<endIdx]
                result = result + Text(String(inner)).italic()
                remaining = remaining[remaining.index(after: endIdx)...]
                continue
            }

            // Plain text until next special char
            let nextSpecial = remaining.dropFirst().firstIndex(where: { $0 == "*" || $0 == "`" })
                ?? remaining.endIndex
            result = result + Text(String(remaining[remaining.startIndex..<nextSpecial]))
            remaining = remaining[nextSpecial...]
        }

        return result
    }
}
