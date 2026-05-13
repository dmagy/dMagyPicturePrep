import SwiftUI
import AppKit

// ================================================================
// HelpView.swift
// Purpose:
// - Presents bundled dMPP Markdown help files in a simple in-app Help window.
// - Uses a topic list on the left and selected Markdown content on the right.
//
// Dependencies & Effects:
// - Reads Markdown files bundled in the app target.
// - Does not modify archive data.
// - Does not require Apple Help Book setup.
//
// Data Flow:
// - Static topic list maps display titles to bundled Markdown filenames.
// - Selected topic loads Markdown from Bundle.main.
// - Markdown is rendered as AttributedString when possible, with plain text fallback.
//
// Section Index:
// - [HELP] Topic model
// - [HELP] Main view
// - [HELP] Content view
// - [HELP] Bundle loading
// ================================================================


// ================================================================
// MARK: - [HELP] Topic model
// ================================================================

private struct DMPPHelpTopic: Identifiable, Hashable {
    let id: String
    let title: String
    let filename: String

    static let all: [DMPPHelpTopic] = [
        DMPPHelpTopic(id: "getting-started", title: "Getting Started", filename: "00-Getting-Started.md"),
        DMPPHelpTopic(id: "picture-library-folder", title: "Picture Library Folder", filename: "01-Picture-Library-Folder.md"),
        DMPPHelpTopic(id: "sidecars", title: "Sidecars and Portable Archive Data", filename: "02-Sidecars-and-Portable-Archive-Data.md"),
        DMPPHelpTopic(id: "editor", title: "The Editor", filename: "03-The-Editor.md"),
        DMPPHelpTopic(id: "saving", title: "Saving Your Work", filename: "04-Saving-Your-Work.md"),
        DMPPHelpTopic(id: "dates", title: "Dates and Eras", filename: "05-Dates-and-Eras.md"),
        DMPPHelpTopic(id: "people", title: "People", filename: "06-People.md"),
        DMPPHelpTopic(id: "locations", title: "Locations", filename: "07-Locations.md"),
        DMPPHelpTopic(id: "tags", title: "Tags", filename: "08-Tags.md"),
        DMPPHelpTopic(id: "crops", title: "Crops", filename: "09-Crops.md"),
        DMPPHelpTopic(id: "private-notes", title: "Curator Notes", filename: "10-Private-Notes.md"),
        DMPPHelpTopic(id: "settings", title: "Settings", filename: "11-Settings.md"),
        DMPPHelpTopic(id: "troubleshooting", title: "Troubleshooting", filename: "12-Troubleshooting.md")
    ]
}


// ================================================================
// MARK: - [HELP] Main view
// ================================================================

struct DMPPHelpView: View {
    @State private var selectedTopicID: String = DMPPHelpTopic.all.first?.id ?? "getting-started"

    private var selectedTopic: DMPPHelpTopic {
        DMPPHelpTopic.all.first { $0.id == selectedTopicID }
        ?? DMPPHelpTopic.all[0]
    }

    var body: some View {
        HStack(spacing: 0) {
            List(DMPPHelpTopic.all, selection: $selectedTopicID) { topic in
                Text(topic.title)
                    .tag(topic.id)
            }
            .listStyle(.sidebar)
            .frame(minWidth: 230, idealWidth: 260, maxWidth: 320)

            Divider()

            DMPPHelpTopicContentView(topic: selectedTopic)
                .id(selectedTopic.id)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .frame(
            minWidth: 760,
            idealWidth: 900,
            minHeight: 560,
            idealHeight: 700
        )
    }
}


// ================================================================
// MARK: - [HELP] Content view
// ================================================================

private struct DMPPHelpTopicContentView: View {
    let topic: DMPPHelpTopic

    private var markdown: String {
        DMPPHelpFileLoader.loadMarkdown(filename: topic.filename)
    }

    private var blocks: [DMPPHelpMarkdownBlock] {
        DMPPHelpMarkdownParser.blocks(from: markdown)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 10) {
                ForEach(Array(blocks.enumerated()), id: \.offset) { _, block in
                    DMPPHelpMarkdownBlockView(block: block)
                }
            }
            .padding(24)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .background(Color(nsColor: .textBackgroundColor))
    }
}


// ================================================================
// MARK: - [HELP] Lightweight Markdown rendering
// ================================================================

private enum DMPPHelpMarkdownBlock: Equatable {
    case heading(level: Int, text: String)
    case paragraph(String)
    case bullet(String)
    case numbered(String)
    case code(String)
}

private struct DMPPHelpMarkdownBlockView: View {
    let block: DMPPHelpMarkdownBlock

    var body: some View {
        switch block {
        case .heading(let level, let text):
            Text(text)
                .font(font(forHeadingLevel: level))
                .fontWeight(level == 1 ? .semibold : .medium)
                .padding(.top, level == 1 ? 2 : 12)
                .padding(.bottom, level == 1 ? 6 : 2)
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)

        case .paragraph(let text):
            Text(text)
                .font(.body)
                .lineSpacing(3)
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)

        case .bullet(let text):
            HStack(alignment: .top, spacing: 8) {
                Text("•")
                    .font(.body)

                Text(text)
                    .font(.body)
                    .lineSpacing(3)
                    .textSelection(.enabled)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

        case .numbered(let text):
            Text(text)
                .font(.body)
                .lineSpacing(3)
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)

        case .code(let text):
            Text(text)
                .font(.system(.body, design: .monospaced))
                .textSelection(.enabled)
                .padding(10)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(Color.secondary.opacity(0.08))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .strokeBorder(Color.secondary.opacity(0.14), lineWidth: 1)
                )
                .padding(.vertical, 2)
        }
    }

    private func font(forHeadingLevel level: Int) -> Font {
        switch level {
        case 1:
            return .title2
        case 2:
            return .title3
        case 3:
            return .headline
        default:
            return .subheadline
        }
    }
}

private enum DMPPHelpMarkdownParser {
    static func blocks(from markdown: String) -> [DMPPHelpMarkdownBlock] {
        let lines = markdown
            .replacingOccurrences(of: "\r\n", with: "\n")
            .replacingOccurrences(of: "\r", with: "\n")
            .components(separatedBy: "\n")

        var blocks: [DMPPHelpMarkdownBlock] = []
        var paragraphLines: [String] = []

        var inCodeBlock = false
        var codeLines: [String] = []

        func flushParagraph() {
            let text = paragraphLines
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty }
                .joined(separator: " ")

            if !text.isEmpty {
                blocks.append(.paragraph(cleanInlineMarkdown(text)))
            }

            paragraphLines.removeAll()
        }

        func flushCode() {
            let text = codeLines.joined(separator: "\n")
                .trimmingCharacters(in: .newlines)

            if !text.isEmpty {
                blocks.append(.code(text))
            }

            codeLines.removeAll()
        }

        for rawLine in lines {
            let line = rawLine.trimmingCharacters(in: .whitespaces)

            if line.hasPrefix("```") {
                if inCodeBlock {
                    flushCode()
                    inCodeBlock = false
                } else {
                    flushParagraph()
                    inCodeBlock = true
                    codeLines.removeAll()
                }
                continue
            }

            if inCodeBlock {
                codeLines.append(rawLine)
                continue
            }

            if line.isEmpty {
                flushParagraph()
                continue
            }

            if let heading = parseHeading(line) {
                flushParagraph()
                blocks.append(.heading(level: heading.level, text: cleanInlineMarkdown(heading.text)))
                continue
            }

            if line.hasPrefix("- ") {
                flushParagraph()
                let text = String(line.dropFirst(2))
                blocks.append(.bullet(cleanInlineMarkdown(text)))
                continue
            }

            if isNumberedListLine(line) {
                flushParagraph()
                blocks.append(.numbered(cleanInlineMarkdown(line)))
                continue
            }

            paragraphLines.append(line)
        }

        if inCodeBlock {
            flushCode()
        }

        flushParagraph()

        return blocks
    }

    private static func parseHeading(_ line: String) -> (level: Int, text: String)? {
        guard line.hasPrefix("#") else { return nil }

        let level = line.prefix { $0 == "#" }.count
        guard level > 0, level <= 6 else { return nil }

        let remainder = line.dropFirst(level)
        guard remainder.first == " " else { return nil }

        let text = remainder.dropFirst().trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return nil }

        return (level, text)
    }

    private static func isNumberedListLine(_ line: String) -> Bool {
        let parts = line.split(separator: ".", maxSplits: 1, omittingEmptySubsequences: false)
        guard parts.count == 2 else { return false }
        guard parts[0].allSatisfy({ $0.isNumber }) else { return false }
        return parts[1].hasPrefix(" ")
    }

    private static func cleanInlineMarkdown(_ text: String) -> String {
        text
            .replacingOccurrences(of: "**", with: "")
            .replacingOccurrences(of: "`", with: "")
    }
}


// ================================================================
// MARK: - [HELP] Bundle loading
// ================================================================

private enum DMPPHelpFileLoader {
    static func loadMarkdown(filename: String) -> String {
        if let url = findHelpFile(filename: filename),
           let text = try? String(contentsOf: url, encoding: .utf8) {
            return text
        }

        return """
        # Help topic not found

        dMPP could not find the bundled help file:

        ```text
        \(filename)
        ```

        Make sure the Markdown file is included in the app target and copied into the app bundle.
        """
    }

    private static func findHelpFile(filename: String) -> URL? {
        let fileURL = URL(fileURLWithPath: filename)
        let resourceName = fileURL.deletingPathExtension().lastPathComponent
        let resourceExtension = fileURL.pathExtension

        // Common case if Xcode flattens individual resource files into the app bundle.
        if let url = Bundle.main.url(
            forResource: resourceName,
            withExtension: resourceExtension
        ) {
            return url
        }

        // Common case if Xcode preserves the Docs/dMPP/Help folder.
        if let url = Bundle.main.url(
            forResource: resourceName,
            withExtension: resourceExtension,
            subdirectory: "Docs/dMPP/Help"
        ) {
            return url
        }

        // Possible case if the files are copied under Help directly.
        if let url = Bundle.main.url(
            forResource: resourceName,
            withExtension: resourceExtension,
            subdirectory: "Help"
        ) {
            return url
        }

        return nil
    }
}
