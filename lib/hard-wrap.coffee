AtomHardWrapView = require './hard-wrap-view'
{CompositeDisposable} = require 'atom'

module.exports = AtomHardWrap =
  atomHardWrapView: null
  modalPanel: null
  subscriptions: null

  activate: (state) ->
    @atomHardWrapView = new AtomHardWrapView(state.atomHardWrapViewState)
    @modalPanel = atom.workspace.addModalPanel(item: @atomHardWrapView.getElement(), visible: false)

    # Events subscribed to in atom's system can be easily cleaned up with a CompositeDisposable
    @subscriptions = new CompositeDisposable

    # Register command that toggles this view
    @subscriptions.add atom.commands.add 'atom-workspace', 'hard-wrap:toggle': => @toggle()

  deactivate: ->
    @modalPanel.destroy()
    @subscriptions.dispose()
    @atomHardWrapView.destroy()

  serialize: ->
    atomHardWrapViewState: @atomHardWrapView.serialize()

  toggle: ->
    console.log 'AtomHardWrap was toggled!'

    if @modalPanel.isVisible()
      @modalPanel.hide()
    else
      @modalPanel.show()
