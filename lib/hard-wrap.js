'use babel'

const {CompositeDisposable} = require('atom')
const _ = require('underscore-plus')
const {max} = _
const repeating = require('repeating')

const CHARACTER_RE = new RegExp(`\
[\
\\w${/* English */''}\
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
      return atom.config.get('editor.preferredLineLength', {scope: textEditor.getRootScopeDescriptor()})
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

        const reflowOptions = {
          wrapColumn: this.getWrapColumn(range, editor),
          tabLength: this.getTabLength(editor),
        }
        const reflowedText = this.reflow(editor.getTextInBufferRange(range), reflowOptions)
        editor.getBuffer().setTextInRange(range, reflowedText)
      }
    })
  },

  // "borrowed" from atom/autoflow
  // TODO: move this to a node module, submit PR to autoflow to use that.
  reflow(text, {wrapColumn, tabLength}) {
    let paragraphs = []
    // Convert all \r\n and \r to \n. the text buffer will normalise them later
    text = text.replace(/\r\n?/g, '\n')

    const paragraphBlocks = text.split(/\n\s*\n/g)
    const tabLengthInSpaces = tabLength != null ? repeating(' ', tabLength) : '';

    for (block of (paragraphBlocks: Array)) {

      // TODO: this could be more language specific. Use the actual comment char.
      const linePrefix = block.match(/^\s*[\/#*-]*\s*/g)[0]
      const linePrefixTabExpanded = tabLength ? linePrefix.replace(/\t/g, tabLengthInSpaces) : linePrefix
      const escapedLinePrefix = linePrefix && _.escapeRegExp(linePrefix)
      let blockLines = block.split('\n')

      if (linePrefix) {
        blockLines = blockLines.map((blockLine) =>
          blockLine.replace(new RegExp(`^${escapedLinePrefix}`), '')
        )
      }

      blockLines = blockLines.map((blockLine) => blockLine.replace(/^\s+/, ''))

      let lines = []
      let currentLine = []
      let currentLineLength = linePrefixTabExpanded.length

      const segments = this.segmentText(blockLines.join(' '))

      for (const segment of (segments: Array)) {
        if (this.wrapSegment(segment, currentLineLength, wrapColumn)) {
          lines.push(linePrefix + currentLine.join(''))
          currentLine = []
          currentLineLength = linePrefixTabExpanded.length
        }
        currentLine.push(segment)
        currentLineLength += segment.length
      }
      lines.push(linePrefix + currentLine.join(''))

      paragraphs.push(lines.join('\n').replace(/\s+\n/g, '\n'))
    }

    return paragraphs.join('\n\n')
  },

  getTabLength(editor) {
    const tabLength = atom.config.get('editor.tabLength', {scope: editor.getRootScopeDescriptor()})
    return tabLength != null ? tabLength : 2
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
