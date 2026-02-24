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
        <meta http-equiv="Content-Security-Policy" content="default-src 'none'; style-src 'unsafe-inline'; img-src data: https:;">
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
        escapeHTML(html.rawHTML)
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
        escapeHTML(html.rawHTML)
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
