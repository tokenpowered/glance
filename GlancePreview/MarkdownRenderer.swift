import Foundation
import Markdown

enum MarkdownRenderer {
    static func render(_ source: String, baseURL: URL) -> String {
        let document = Document(parsing: source)
        var converter = HTMLConverter(baseURL: baseURL)
        let body = converter.visit(document)
        return """
        <!DOCTYPE html>
        <html>
        <head>
        <meta charset="utf-8">
        <meta name="viewport" content="width=device-width, initial-scale=1">
        <meta name="color-scheme" content="light dark">
        <meta http-equiv="Content-Security-Policy" content="default-src 'none'; style-src 'unsafe-inline'; img-src data: http: https:;">
        <style>
        \(StyleSheet.css)
        </style>
        </head>
        <body>
        \(body)
        </body>
        </html>
        """
    }
}

struct HTMLConverter: MarkupVisitor {
    typealias Result = String

    let baseURL: URL

    mutating func defaultVisit(_ markup: any Markup) -> String {
        markup.children.map { visit($0) }.joined()
    }

    // MARK: - Block elements

    mutating func visitDocument(_ document: Document) -> String {
        document.children.map { visit($0) }.joined()
    }

    mutating func visitHeading(_ heading: Heading) -> String {
        let content = heading.children.map { visit($0) }.joined()
        return "<h\(heading.level)>\(content)</h\(heading.level)>\n"
    }

    mutating func visitParagraph(_ paragraph: Paragraph) -> String {
        let content = paragraph.children.map { visit($0) }.joined()
        return "<p>\(content)</p>\n"
    }

    mutating func visitBlockQuote(_ blockQuote: BlockQuote) -> String {
        let content = blockQuote.children.map { visit($0) }.joined()
        return "<blockquote>\(content)</blockquote>\n"
    }

    mutating func visitOrderedList(_ orderedList: OrderedList) -> String {
        let content = orderedList.children.map { visit($0) }.joined()
        let start = orderedList.startIndex != 1 ? " start=\"\(orderedList.startIndex)\"" : ""
        return "<ol\(start)>\(content)</ol>\n"
    }

    mutating func visitUnorderedList(_ unorderedList: UnorderedList) -> String {
        let content = unorderedList.children.map { visit($0) }.joined()
        return "<ul>\(content)</ul>\n"
    }

    mutating func visitListItem(_ listItem: ListItem) -> String {
        let content = listItem.children.map { visit($0) }.joined()
        if let checkbox = listItem.checkbox {
            let checked = checkbox == .checked ? " checked" : ""
            // Strip the first <p></p> wrapper so checkbox and label stay inline
            // but preserve subsequent paragraphs if present
            var inline = content
            if inline.hasPrefix("<p>"), let end = inline.range(of: "</p>") {
                inline.removeSubrange(inline.startIndex..<inline.index(inline.startIndex, offsetBy: 3))
                inline.removeSubrange(end)
            }
            let trimmed = inline.trimmingCharacters(in: .whitespacesAndNewlines)
            return "<li class=\"task-item\"><input type=\"checkbox\" disabled\(checked)> \(trimmed)</li>\n"
        }
        return "<li>\(content)</li>\n"
    }

    mutating func visitCodeBlock(_ codeBlock: CodeBlock) -> String {
        let escaped = escapeHTML(codeBlock.code)
        let langAttr: String
        if let lang = codeBlock.language {
            langAttr = " class=\"language-\(escapeHTML(lang))\""
        } else {
            langAttr = ""
        }
        return "<pre><code\(langAttr)>\(escaped)</code></pre>\n"
    }

    mutating func visitThematicBreak(_ thematicBreak: ThematicBreak) -> String {
        "<hr>\n"
    }

    mutating func visitHTMLBlock(_ html: HTMLBlock) -> String {
        sanitizeHTML(html.rawHTML)
    }

    mutating func visitTable(_ table: Table) -> String {
        let content = table.children.map { visit($0) }.joined()
        return "<table>\(content)</table>\n"
    }

    mutating func visitTableHead(_ tableHead: Table.Head) -> String {
        let cells = tableHead.children.map { visit($0) }.joined()
        return "<thead><tr>\(cells)</tr></thead>\n"
    }

    mutating func visitTableBody(_ tableBody: Table.Body) -> String {
        let rows = tableBody.children.map { visit($0) }.joined()
        return "<tbody>\(rows)</tbody>\n"
    }

    mutating func visitTableRow(_ tableRow: Table.Row) -> String {
        let cells = tableRow.children.map { visit($0) }.joined()
        return "<tr>\(cells)</tr>\n"
    }

    mutating func visitTableCell(_ tableCell: Table.Cell) -> String {
        let content = tableCell.children.map { visit($0) }.joined()
        let tag = tableCell.parent is Table.Head ? "th" : "td"

        var styleAttr = ""
        let columnIndex = tableCell.indexInParent
        var ancestor = tableCell.parent
        while ancestor != nil, !(ancestor is Table) {
            ancestor = ancestor?.parent
        }
        if let table = ancestor as? Table {
            let alignments = table.columnAlignments
            if columnIndex < alignments.count, let alignment = alignments[columnIndex] {
                switch alignment {
                case .center:
                    styleAttr = " style=\"text-align: center\""
                case .right:
                    styleAttr = " style=\"text-align: right\""
                case .left:
                    styleAttr = " style=\"text-align: left\""
                }
            }
        }

        return "<\(tag)\(styleAttr)>\(content)</\(tag)>"
    }

    // MARK: - Inline elements

    mutating func visitText(_ text: Text) -> String {
        escapeHTML(text.string)
    }

    mutating func visitStrong(_ strong: Strong) -> String {
        let content = strong.children.map { visit($0) }.joined()
        return "<strong>\(content)</strong>"
    }

    mutating func visitEmphasis(_ emphasis: Emphasis) -> String {
        let content = emphasis.children.map { visit($0) }.joined()
        return "<em>\(content)</em>"
    }

    mutating func visitInlineCode(_ inlineCode: InlineCode) -> String {
        "<code>\(escapeHTML(inlineCode.code))</code>"
    }

    mutating func visitLink(_ link: Link) -> String {
        let content = link.children.map { visit($0) }.joined()
        let href = link.destination ?? ""
        return "<a href=\"\(escapeHTML(href))\">\(content)</a>"
    }

    mutating func visitImage(_ image: Image) -> String {
        let alt = image.children.map { visit($0) }.joined()
        guard let source = image.source else {
            return "<img alt=\"\(alt)\">"
        }

        let src: String
        if source.hasPrefix("http://") || source.hasPrefix("https://") {
            src = escapeHTML(source)
        } else {
            let resolved = baseURL.appendingPathComponent(source)
            let resolvedStandard = resolved.standardizedFileURL
            let baseStandard = baseURL.standardizedFileURL

            if !resolvedStandard.path.hasPrefix(baseStandard.path) {
                src = escapeHTML(source)
            } else if let attrs = try? FileManager.default.attributesOfItem(atPath: resolvedStandard.path),
                      let fileSize = attrs[.size] as? Int,
                      fileSize > 10_485_760 {
                src = escapeHTML(source)
            } else if let data = try? Data(contentsOf: resolved) {
                let mime = mimeType(for: resolved.pathExtension)
                src = "data:\(mime);base64,\(data.base64EncodedString())"
            } else {
                src = escapeHTML(source)
            }
        }

        let titleAttr: String
        if let title = image.title {
            titleAttr = " title=\"\(escapeHTML(title))\""
        } else {
            titleAttr = ""
        }

        return "<img src=\"\(src)\" alt=\"\(alt)\"\(titleAttr)>"
    }

    mutating func visitStrikethrough(_ strikethrough: Strikethrough) -> String {
        let content = strikethrough.children.map { visit($0) }.joined()
        return "<del>\(content)</del>"
    }

    mutating func visitSoftBreak(_ softBreak: SoftBreak) -> String {
        "\n"
    }

    mutating func visitLineBreak(_ lineBreak: LineBreak) -> String {
        "<br>\n"
    }

    mutating func visitInlineHTML(_ html: InlineHTML) -> String {
        sanitizeHTML(html.rawHTML)
    }

    // MARK: - HTML sanitization

    /// Matches <img> tags in raw HTML, correctly handling `>` inside quoted
    /// attribute values (e.g. alt="a > b").
    private static let imgPattern = try! NSRegularExpression(
        pattern: #"<img\b(?:[^>"']|"[^"]*"|'[^']*')*>"#,
        options: [.caseInsensitive, .dotMatchesLineSeparators]
    )

    /// Passes allowlisted HTML tags through after sanitizing their attributes.
    /// All non-allowlisted content is escaped.
    private mutating func sanitizeHTML(_ raw: String) -> String {
        let nsRange = NSRange(raw.startIndex..., in: raw)
        let matches = Self.imgPattern.matches(in: raw, range: nsRange)

        if matches.isEmpty {
            return escapeHTML(raw)
        }

        var result = ""
        var cursor = raw.startIndex

        for match in matches {
            guard let range = Range(match.range, in: raw) else { continue }

            // Escape everything before this <img> tag
            if cursor < range.lowerBound {
                result += escapeHTML(String(raw[cursor..<range.lowerBound]))
            }

            result += sanitizeImgTag(String(raw[range]))
            cursor = range.upperBound
        }

        // Escape anything remaining after the last match
        if cursor < raw.endIndex {
            result += escapeHTML(String(raw[cursor...]))
        }

        return result
    }

    /// Attribute pattern: name="value", name='value', or name=bare.
    /// Bare values stop at whitespace or `>` to avoid capturing the tag close.
    private static let attrPattern = try! NSRegularExpression(
        pattern: #"(\w[\w-]*)\s*=\s*(?:"([^"]*)"|'([^']*)'|([^\s>]+))"#,
        options: [.caseInsensitive]
    )

    private static let allowedImgAttrs: Set<String> = [
        "src", "alt", "width", "height", "title", "style",
    ]

    /// CSS properties allowed in style attributes. Everything else is stripped.
    private static let allowedCSSProperties: Set<String> = [
        "max-width", "max-height", "width", "height",
        "display", "margin", "margin-top", "margin-right", "margin-bottom", "margin-left",
        "text-align", "vertical-align",
        "border", "border-radius", "padding",
    ]

    /// Sanitizes a CSS style string to only include allowlisted properties.
    private static func sanitizeStyle(_ style: String) -> String {
        style
            .split(separator: ";")
            .compactMap { declaration -> String? in
                let parts = declaration.split(separator: ":", maxSplits: 1)
                guard parts.count == 2 else { return nil }
                let property = parts[0].trimmingCharacters(in: .whitespaces).lowercased()
                let value = parts[1].trimmingCharacters(in: .whitespaces)
                guard allowedCSSProperties.contains(property) else { return nil }
                // Block url() and expression() in values
                let lower = value.lowercased()
                guard !lower.contains("url("), !lower.contains("expression(") else { return nil }
                return "\(property): \(value)"
            }
            .joined(separator: "; ")
    }

    /// Sanitizes an <img> tag: extracts only allowlisted attributes and
    /// applies the same local-file security as visitImage (path traversal
    /// protection, size limit, base64 inlining).
    private mutating func sanitizeImgTag(_ tag: String) -> String {
        let nsRange = NSRange(tag.startIndex..., in: tag)
        let matches = Self.attrPattern.matches(in: tag, range: nsRange)

        var attrs: [(name: String, value: String)] = []
        for match in matches {
            guard let nameRange = Range(match.range(at: 1), in: tag) else { continue }
            let name = String(tag[nameRange]).lowercased()

            guard Self.allowedImgAttrs.contains(name) else { continue }

            // Value is in group 2 (double-quoted), 3 (single-quoted), or 4 (bare)
            let value: String
            if let r = Range(match.range(at: 2), in: tag) {
                value = String(tag[r])
            } else if let r = Range(match.range(at: 3), in: tag) {
                value = String(tag[r])
            } else if let r = Range(match.range(at: 4), in: tag) {
                value = String(tag[r])
            } else {
                value = ""
            }

            attrs.append((name: name, value: value))
        }

        // Reject dangerous URI schemes in src
        if let srcEntry = attrs.first(where: { $0.name == "src" }) {
            let lower = srcEntry.value.trimmingCharacters(in: .whitespaces).lowercased()
            if lower.hasPrefix("javascript:") || lower.hasPrefix("data:") {
                return escapeHTML(tag)
            }
        }

        // Process src the same way visitImage does: inline local files as
        // base64 with path traversal protection, pass remote URLs through.
        // Sanitize style values with a CSS property allowlist.
        var processedAttrs: [(name: String, value: String)] = []
        for attr in attrs {
            if attr.name == "src" {
                processedAttrs.append((name: "src", value: resolveImageSrc(attr.value)))
            } else if attr.name == "style" {
                let sanitized = Self.sanitizeStyle(attr.value)
                if !sanitized.isEmpty {
                    processedAttrs.append((name: "style", value: sanitized))
                }
            } else {
                processedAttrs.append(attr)
            }
        }

        // Build the clean tag
        let attrString = processedAttrs
            .map { "\($0.name)=\"\(escapeHTML($0.value))\"" }
            .joined(separator: " ")

        if attrString.isEmpty {
            return "<img>"
        }
        return "<img \(attrString)>"
    }

    /// Resolves an image src value using the same logic as visitImage:
    /// remote URLs pass through, local paths get base64-inlined with path
    /// traversal protection and a 10 MB size cap.
    private func resolveImageSrc(_ source: String) -> String {
        if source.hasPrefix("http://") || source.hasPrefix("https://") || source.hasPrefix("data:") {
            return source
        }

        let resolved = baseURL.appendingPathComponent(source)
        let resolvedStandard = resolved.standardizedFileURL
        let baseStandard = baseURL.standardizedFileURL

        guard resolvedStandard.path.hasPrefix(baseStandard.path) else {
            return source
        }

        guard let attrs = try? FileManager.default.attributesOfItem(atPath: resolvedStandard.path),
              let fileSize = attrs[.size] as? Int,
              fileSize <= 10_485_760 else {
            return source
        }

        guard let data = try? Data(contentsOf: resolved) else {
            return source
        }

        let mime = mimeType(for: resolved.pathExtension)
        return "data:\(mime);base64,\(data.base64EncodedString())"
    }

    // MARK: - Helpers

    private func escapeHTML(_ string: String) -> String {
        string
            .replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
            .replacingOccurrences(of: "\"", with: "&quot;")
            .replacingOccurrences(of: "'", with: "&#39;")
    }

    private func mimeType(for ext: String) -> String {
        switch ext.lowercased() {
        case "png": return "image/png"
        case "jpg", "jpeg": return "image/jpeg"
        case "gif": return "image/gif"
        case "svg": return "image/svg+xml"
        case "webp": return "image/webp"
        case "bmp": return "image/bmp"
        case "ico": return "image/x-icon"
        default: return "application/octet-stream"
        }
    }
}
