{CompositeDisposable} = require 'atom'
{max} = require 'underscore-plus'

module.exports = AtomHardWrap =
  modalPanel: null
  subscriptions: null

  activate: (state) ->
    @subscriptions = new CompositeDisposable

    # Register command that toggles this view
    @subscriptions.add atom.commands.add 'atom-text-editor',
      'hard-wrap:execute': => @execute()

  deactivate: ->
    @modalPanel.destroy()
    @subscriptions.dispose()

  getMaxLineLength: (selection, textEditor) ->
    maxLen = 0
    for row in selection.getBufferRange().getRows()
      len = textEditor.lineTextForBufferRow(row).length
      if len > maxLen
        maxLen = len
    return maxLen

  getWrapColumn: (selection, textEditor) ->
    unless atom.packages.isPackageLoaded('multi-wrap-guide')
      return atom.config.get('editor.preferredLineLength')

    try
      textEditorView = atom.views.getView(textEditor)
      wrapGuideView = textEditorView.rootElement.querySelector('.multi-wrap-guide-view')
      columns = wrapGuideView.spacePenView.columns
      if columns.length is 0
        return atom.config.get('editor.preferredLineLength')
      if columns.length is 1
        return columns[0]
      maxLineLength = @getMaxLineLength(selection, textEditor)
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

  execute: ->
    console.log 'AtomHardWrap was executed!'

    textEditor = atom.workspace.getActiveTextEditor()
    for selection in textEditor.getSelections()
      selection.selectToBeginningOfLine()
      selection.selectToEndOfLine()

      wrapColumn = @getWrapColumn(selection, textEditor)
      wrappedText = @wrapText(selection.getText(), wrapColumn)
      selection.insertText(wrappedText, {select: true})
