{CompositeDisposable} = require 'atom'
{max} = _ = require 'underscore-plus'

module.exports = AtomHardWrap =
  subscriptions: null

  activate: (state) ->
    @subscriptions = new CompositeDisposable

    # Register command that toggles this view
    @subscriptions.add atom.commands.add 'atom-text-editor',
      'hard-wrap:reflow-selection': => @reflowSelection()

  deactivate: ->
    @subscriptions.dispose()

  getMaxLineLength: (range, textEditor) ->
    maxLen = 0
    for row in range.getBufferRange().getRows()
      len = textEditor.lineTextForBufferRow(row).length
      if len > maxLen
        maxLen = len
    return maxLen

  getWrapColumn: (range, textEditor) ->
    unless atom.packages.isPackageLoaded('multi-wrap-guide')
      return atom.config.get('editor.preferredLineLength')

    try
      textEditorView = atom.views.getView(textEditor)
      wrapGuideView =
        textEditorView.rootElement.querySelector('.multi-wrap-guide-view')
      columns = wrapGuideView.spacePenView.columns
      if columns.length is 0
        return atom.config.get('editor.preferredLineLength')
      if columns.length is 1
        return columns[0]
      maxLineLength = @getMaxLineLength(range, textEditor)
      maxCol = 0
      for col in columns
        if col < maxLineLength and col > maxCol
          maxCol = col
      if maxCol is 0
        maxCol = max(columns)
      return maxCol

    catch e
      return atom.config.get('editor.preferredLineLength')

  reflowSelection: ->
    editor = atom.workspace.getActiveTextEditor()
    editor.transact =>
      for range in editor.getSelectedBufferRanges()
        # selection.selectToBeginningOfLine()
        # selection.selectToEndOfLine()
        if range.isEmpty()
          range = editor.languageMode.
            rowRangeForParagraphAtBufferRow(range.getRows()[0])
          if not range?
            continue # nothing to do here

        wrapColumn = @getWrapColumn(range, editor)
        reflowedText = @reflow(editor.getTextInBufferRange(range), {wrapColumn})
        editor.getBuffer().setTextInRange(range, reflowedText)

  # copied from atom/autoflow
  # TODO: move this to a node module, submit PR to autoflow to use that.
  reflow: (text, {wrapColumn}) ->
    paragraphs = []
    paragraphBlocks = text.split(/\n\s*\n/g)

    for block in paragraphBlocks

      # TODO: this could be more language specific. Use the actual comment char.
      linePrefix = block.match(/^\s*[\/#*-]*\s*/g)[0]
      blockLines = block.split('\n')

      if linePrefix
        escapedLinePrefix = _.escapeRegExp(linePrefix)
        blockLines = blockLines.map (blockLine) ->
          blockLine.replace(///^#{escapedLinePrefix}///, '')

      blockLines = blockLines.map (blockLine) ->
        blockLine.replace(/^\s+/, '')

      lines = []
      currentLine = []
      currentLineLength = linePrefix.length

      for segment in @segmentText(blockLines.join(' '))
        if @wrapSegment(segment, currentLineLength, wrapColumn)
          lines.push(linePrefix + currentLine.join(''))
          currentLine = []
          currentLineLength = linePrefix.length
        currentLine.push(segment)
        currentLineLength += segment.length
      lines.push(linePrefix + currentLine.join(''))

      paragraphs.push(lines.join('\n').replace(/\s+\n/g, '\n'))

    paragraphs.join('\n\n')

  wrapSegment: (segment, currentLineLength, wrapColumn) ->
    /\w/.test(segment) and
      (currentLineLength + segment.length > wrapColumn) and
      (currentLineLength > 0 or segment.length < wrapColumn)

  segmentText: (text) ->
    segments = []
    re = /[\s]+|[^\s]+/g
    segments.push(match[0]) while match = re.exec(text)
    segments
