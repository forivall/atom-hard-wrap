'use babel'

const {CompositeDisposable} = require('atom')
const _ = require('underscore-plus')
const {max} = _

const CHARACTER_RE = new Regex(`\
[\
\w${/* English */''}\
\u0410-\u042F\u0401\u0430-\u044F\u0451${/* Cyrillic */''}\
]\
`)

const AtomHardWrap = module.exports = {
  subscriptions: null,

  activate(state) {
    this.subscriptions = new CompositeDisposable()

    // Register command that toggles this view
    this.subscriptions.add(atom.commands.add('atom-text-editor', {
      'hard-wrap:reflow-selection': () => this.reflowSelection()
    }))
  },

  deactivate() {
    this.subscriptions.dispose()
  },

  getMaxLineLength(range, textEditor) {
    let maxLen = 0
    for (row of (range.getBufferRange().getRows(): Array)) {
      let len = textEditor.lineTextForBufferRow(row).length
      if (len > maxLen) {
        maxLen = len
      }
    }
    return maxLen
  },

  getWrapColumn(range, textEditor) {
    if (!atom.packages.isPackageLoaded('multi-wrap-guide')) {
      return atom.config.get('editor.preferredLineLength')
    }

    try {
      const textEditorView = atom.views.getView(textEditor)
      const wrapGuideView =
        textEditorView.rootElement.querySelector('.multi-wrap-guide-view')
      const columns = wrapGuideView.spacePenView.columns
      if (columns.length === 0) {
        return atom.config.get('editor.preferredLineLength')
      }
      if (columns.length === 1) {
        return columns[0]
      }
      const maxLineLength = this.getMaxLineLength(range, textEditor)
      let maxCol = 0
      for (col of (columns: Array)) {
        if (col < maxLineLength && col > maxCol) {
          maxCol = col
        }
      }
      if (maxCol === 0) maxCol = max(columns)
      return maxCol
    }
    catch (e) {
      return atom.config.get('editor.preferredLineLength')
    }
  },

  reflowSelection() {
    const editor = atom.workspace.getActiveTextEditor()
    editor.transact(() => {
      for (let range of (editor.getSelectedBufferRanges(): Array)) {
        // selection.selectToBeginningOfLine()
        // selection.selectToEndOfLine()
        if (range.isEmpty()) {
          range = editor.languageMode.
            rowRangeForParagraphAtBufferRow(range.getRows()[0])
          if (range == null) continue // nothing to do here
        }

        const wrapColumn = this.getWrapColumn(range, editor)
        const reflowedText = this.reflow(editor.getTextInBufferRange(range), {wrapColumn})
        editor.getBuffer().setTextInRange(range, reflowedText)
      }
    })
  },

  // "borrowed" from atom/autoflow
  // TODO: move this to a node module, submit PR to autoflow to use that.
  reflow(text, {wrapColumn}) {
    let paragraphs = []
    const paragraphBlocks = text.split(/\n\s*\n/g)

    for (block of (paragraphBlocks: Array)) {

      // TODO: this could be more language specific. Use the actual comment char.
      const linePrefix = block.match(/^\s*[\/#*-]*\s*/g)[0]
      const escapedLinePrefix = linePrefix && _.escapeRegExp(linePrefix)
      let blockLines = block.split('\n')

      if (linePrefix) {
        blockLines = blockLines.map((blockLine) =>
          blockLine.replace(new Regex(`^${escapedLinePrefix}`), '')
        )
      }

      blockLines = blockLines.map((blockLine) => blockLine.replace(/^\s+/, ''))

      let lines = []
      let currentLine = []
      let currentLineLength = linePrefix.length

      for (segment of (this.segmentText(blockLines.join(' ')): Array)) {
        if (this.wrapSegment(segment, currentLineLength, wrapColumn)) {
          lines.push(linePrefix + currentLine.join(''))
          currentLine = []
          currentLineLength = linePrefix.length
        }
        currentLine.push(segment)
        currentLineLength += segment.length
      }
      lines.push(linePrefix + currentLine.join(''))

      paragraphs.push(lines.join('\n').replace(/\s+\n/g, '\n'))
    }

    paragraphs.join('\n\n')
  },

  wrapSegment(segment, currentLineLength, wrapColumn) {
    return (
      CHARACTER_RE.test(segment) &&
      (currentLineLength + segment.length > wrapColumn) &&
      (currentLineLength > 0 || segment.length < wrapColumn) &&
    true)
  },

  segmentText(text) {
    let segments = []
    const re = /[\s]+|[^\s]+/g
    while (match = re.exec(text)) segments.push(match[0])
    return segments
  },
}
