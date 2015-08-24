{CompositeDisposable} = require 'atom'
{max} = require 'underscore-plus'

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

  wrapText: (text, lineLength) ->
    wrapped = ""
    words = text.split(/\s+/)
    charcount = 0
    for w in words
      n = w.length + 1
      if charcount + n >= lineLength
        wrapped += "\n"
        charcount = 0
      wrapped += w + " "
      charcount += n
    return wrapped

  reflowSelection: ->
    editor = atom.workspace.getActiveTextEditor()
    for range in editor.getSelectedBufferRanges()
      # selection.selectToBeginningOfLine()
      # selection.selectToEndOfLine()
      if range.isEmpty()
        range = editor.languageMode.
          rowRangeForParagraphAtBufferRow(range.getRows()[0])

      wrapColumn = @getWrapColumn(range, editor)
      reflowedText = @reflow(editor.getTextInBufferRange(range), {wrapColumn})
      editor.getBuffer().setTextInRange(range, reflowedText)
