import SwiftUI

/// A block of parsed Markdown.
private enum MarkdownBlock {
    case heading(level: Int, text: String)
    case paragraph(String)
    case bullet(String)
    case ordered(marker: String, text: String)
    case quote(String)
    case code(String)
}

/// Lightweight Markdown renderer for translation output: headings, bullet and
/// numbered lists, fenced code blocks, block quotes, and inline emphasis / code
/// / links. Dependency-free and RTL-aware (markers and alignment mirror for
/// Arabic; code blocks stay left-to-right).
struct MarkdownText: View {
    let markdown: String
    let isRTL: Bool

    private var blocks: [(Int, MarkdownBlock)] {
        Array(MarkdownParser.parse(markdown).enumerated())
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            ForEach(blocks, id: \.0) { _, block in
                row(block)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .foregroundStyle(Theme.textPrimary)
        .tint(Theme.lapis)
        .multilineTextAlignment(.leading)
        .environment(\.layoutDirection, isRTL ? .rightToLeft : .leftToRight)
        .textSelection(.enabled)
    }

    @ViewBuilder
    private func row(_ block: MarkdownBlock) -> some View {
        switch block {
        case .heading(let level, let text):
            inline(text)
                .font(.system(size: headingSize(level), weight: .bold))
                .frame(maxWidth: .infinity, alignment: .leading)
        case .paragraph(let text):
            inline(text)
                .font(.system(size: 15))
                .frame(maxWidth: .infinity, alignment: .leading)
        case .bullet(let text):
            listRow(marker: "•", text: text)
        case .ordered(let marker, let text):
            listRow(marker: marker, text: text)
        case .quote(let text):
            inline(text)
                .font(.system(size: 15))
                .italic()
                .foregroundStyle(Theme.textSecondary)
                .padding(.leading, 10)
                .overlay(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 1).fill(Theme.gold.opacity(0.6)).frame(width: 2)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
        case .code(let code):
            Text(code)
                .font(.system(size: 13, design: .monospaced))
                .foregroundStyle(Theme.textPrimary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(9)
                .background(RoundedRectangle(cornerRadius: 8, style: .continuous).fill(Theme.field))
                .overlay(RoundedRectangle(cornerRadius: 8, style: .continuous).strokeBorder(Theme.stroke, lineWidth: 1))
                // Code reads left-to-right regardless of UI/translation direction.
                .environment(\.layoutDirection, .leftToRight)
        }
    }

    private func listRow(marker: String, text: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 7) {
            Text(marker)
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(Theme.textSecondary)
            inline(text)
                .font(.system(size: 15))
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    /// Renders inline Markdown (bold, italic, code, links) while preserving spacing.
    private func inline(_ text: String) -> Text {
        let options = AttributedString.MarkdownParsingOptions(
            interpretedSyntax: .inlineOnlyPreservingWhitespace
        )
        if let attributed = try? AttributedString(markdown: text, options: options) {
            return Text(attributed)
        }
        return Text(text)
    }

    private func headingSize(_ level: Int) -> CGFloat {
        switch level {
        case 1: return 21
        case 2: return 18
        case 3: return 16.5
        default: return 15.5
        }
    }
}

private enum MarkdownParser {
    static func parse(_ text: String) -> [MarkdownBlock] {
        var blocks: [MarkdownBlock] = []
        let lines = text.components(separatedBy: "\n")
        var paragraph: [String] = []
        var i = 0

        func flushParagraph() {
            guard !paragraph.isEmpty else { return }
            blocks.append(.paragraph(paragraph.joined(separator: "\n")))
            paragraph.removeAll()
        }

        while i < lines.count {
            let line = lines[i]
            let trimmed = line.trimmingCharacters(in: .whitespaces)

            // Fenced code block.
            if trimmed.hasPrefix("```") {
                flushParagraph()
                var code: [String] = []
                i += 1
                while i < lines.count, !lines[i].trimmingCharacters(in: .whitespaces).hasPrefix("```") {
                    code.append(lines[i])
                    i += 1
                }
                if i < lines.count { i += 1 } // skip closing fence
                blocks.append(.code(code.joined(separator: "\n")))
                continue
            }

            if trimmed.isEmpty {
                flushParagraph()
                i += 1
                continue
            }

            // Heading: #, ##, …
            if let range = trimmed.range(of: #"^#{1,6}[ \t]+"#, options: .regularExpression) {
                flushParagraph()
                let level = trimmed.prefix(while: { $0 == "#" }).count
                blocks.append(.heading(level: min(level, 6), text: String(trimmed[range.upperBound...])))
                i += 1
                continue
            }

            // Block quote.
            if trimmed.hasPrefix(">") {
                flushParagraph()
                blocks.append(.quote(String(trimmed.dropFirst()).trimmingCharacters(in: .whitespaces)))
                i += 1
                continue
            }

            // Unordered list: -, *, +
            if let range = trimmed.range(of: #"^[-*+][ \t]+"#, options: .regularExpression) {
                flushParagraph()
                blocks.append(.bullet(String(trimmed[range.upperBound...])))
                i += 1
                continue
            }

            // Ordered list: 1. or 1)
            if let range = trimmed.range(of: #"^\d{1,3}[.)][ \t]+"#, options: .regularExpression) {
                flushParagraph()
                let number = trimmed.prefix(while: { $0.isNumber })
                blocks.append(.ordered(marker: "\(number).", text: String(trimmed[range.upperBound...])))
                i += 1
                continue
            }

            paragraph.append(line)
            i += 1
        }
        flushParagraph()
        return blocks
    }
}
