enum StyleSheet {
    static let css = """
    :root {
        color-scheme: light dark;
        --subtle-bg: rgba(128,128,128,0.08);
    }

    body {
        font-family: -apple-system, BlinkMacSystemFont, "Helvetica Neue", Helvetica, Arial, sans-serif;
        -webkit-font-smoothing: antialiased;
        font-size: 16px;
        line-height: 1.6;
        max-width: 720px;
        margin: 0 auto;
        padding: 24px;
        color: -apple-system-label;
        background: transparent;
    }

    h1, h2, h3, h4, h5, h6 {
        margin-top: 1.4em;
        margin-bottom: 0.6em;
        font-weight: 600;
        line-height: 1.25;
    }
    h1 { font-size: 2em; border-bottom: 1px solid -apple-system-separator; padding-bottom: 0.3em; }
    h2 { font-size: 1.5em; border-bottom: 1px solid -apple-system-separator; padding-bottom: 0.3em; }
    h3 { font-size: 1.25em; }

    p { margin: 0 0 1em; }

    a { color: -apple-system-blue; text-decoration: none; }

    code {
        font-family: "SF Mono", SFMono-Regular, Menlo, monospace;
        font-size: 0.9em;
        background: var(--subtle-bg);
        padding: 0.2em 0.4em;
        border-radius: 4px;
    }

    pre {
        background: var(--subtle-bg);
        padding: 16px;
        border-radius: 6px;
        overflow-x: auto;
        margin: 0 0 1em;
    }
    pre code {
        background: none;
        padding: 0;
        font-size: 0.85em;
    }

    blockquote {
        margin: 0 0 1em;
        padding: 0.5em 1em;
        border-left: 4px solid -apple-system-separator;
        color: -apple-system-secondary-label;
    }
    blockquote p:last-child { margin-bottom: 0; }

    ul, ol { padding-left: 2em; margin: 0 0 1em; }
    li { margin: 0.25em 0; }
    li > p { margin: 0; }

    li.task-item {
        list-style: none;
        margin-left: -1.4em;
    }
    li.task-item input[type="checkbox"] {
        margin-right: 0.4em;
    }

    hr {
        border: none;
        border-top: 1px solid -apple-system-separator;
        margin: 2em 0;
    }

    img {
        max-width: 100%;
        height: auto;
        border-radius: 4px;
    }

    table {
        border-collapse: collapse;
        width: 100%;
        margin: 0 0 1em;
    }
    th, td {
        border: 1px solid -apple-system-separator;
        padding: 8px 12px;
        text-align: left;
    }
    th {
        background: var(--subtle-bg);
        font-weight: 600;
    }

    del { text-decoration: line-through; color: -apple-system-secondary-label; }
    """
}
