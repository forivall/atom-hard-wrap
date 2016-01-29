
fs = require('fs')
path = require('path')
trimEnd = (s) -> s.replace(/[\s\uFEFF\xA0]+$/g, '')

describe "AtomHardWrap package", ->
  [hardwrap, editor, editorElement] = []
  tabLength = 4

  beforeEach ->
    activationPromise = null

    waitsForPromise ->
      atom.workspace.open()

    runs ->
      editor = atom.workspace.getActiveTextEditor()
      editorElement = atom.views.getView(editor)

      atom.config.set('editor.preferredLineLength', 30)
      atom.config.set('editor.tabLength', tabLength)

      activationPromise = atom.packages.activatePackage('hard-wrap')

      atom.commands.dispatch editorElement, 'hard-wrap:reflow-selection'

    waitsForPromise ->
      activationPromise

  describe "duplicated behaviour from autoflow", ->

    it "uses the preferred line length based on the editor's scope", ->
      atom.config.set('editor.preferredLineLength', 4, scopeSelector: '.text.plain.null-grammar')
      editor.setText("foo bar")
      editor.selectAll()
      atom.commands.dispatch editorElement, 'hard-wrap:reflow-selection'

      expect(editor.getText()).toEqual """
        foo
        bar
      """

    it "rearranges line breaks in the current selection to ensure lines are shorter than config.editor.preferredLineLength honoring tabLength", ->
      editor.setText "\t\tThis is the first paragraph and it is longer than the preferred line length so it should be reflowed.\n\n\t\tThis is a short paragraph.\n\n\t\tAnother long paragraph, it should also be reflowed with the use of this single command."

      editor.selectAll()
      atom.commands.dispatch editorElement, 'hard-wrap:reflow-selection'

      exedOut = editor.getText().replace(/\t/g, Array(tabLength+1).join 'X')
      expect(exedOut).toEqual "XXXXXXXXThis is the first\nXXXXXXXXparagraph and it is\nXXXXXXXXlonger than the\nXXXXXXXXpreferred line length\nXXXXXXXXso it should be\nXXXXXXXXreflowed.\n\nXXXXXXXXThis is a short\nXXXXXXXXparagraph.\n\nXXXXXXXXAnother long\nXXXXXXXXparagraph, it should\nXXXXXXXXalso be reflowed with\nXXXXXXXXthe use of this single\nXXXXXXXXcommand."

    it "rearranges line breaks in the current selection to ensure lines are shorter than config.editor.preferredLineLength", ->
      editor.setText """
        This is the first paragraph and it is longer than the preferred line length so it should be reflowed.

        This is a short paragraph.

        Another long paragraph, it should also be reflowed with the use of this single command.
      """

      editor.selectAll()
      atom.commands.dispatch editorElement, 'hard-wrap:reflow-selection'

      expect(editor.getText()).toEqual """
        This is the first paragraph
        and it is longer than the
        preferred line length so it
        should be reflowed.

        This is a short paragraph.

        Another long paragraph, it
        should also be reflowed with
        the use of this single
        command.
      """

    it "reflows the current paragraph if nothing is selected", ->
      editor.setText """
        This is a preceding paragraph, which shouldn't be modified by a reflow of the following paragraph.

        The quick brown fox jumps over the lazy
        dog. The preceding sentence contains every letter
        in the entire English alphabet, which has absolutely no relevance
        to this test.

        This is a following paragraph, which shouldn't be modified by a reflow of the preciding paragraph.

      """

      editor.setCursorBufferPosition([3, 5])
      atom.commands.dispatch editorElement, 'hard-wrap:reflow-selection'

      expect(editor.getText()).toEqual """
        This is a preceding paragraph, which shouldn't be modified by a reflow of the following paragraph.

        The quick brown fox jumps over
        the lazy dog. The preceding
        sentence contains every letter
        in the entire English
        alphabet, which has absolutely
        no relevance to this test.

        This is a following paragraph, which shouldn't be modified by a reflow of the preciding paragraph.

      """

    it "allows for single words that exceed the preferred wrap column length", ->
      editor.setText("this-is-a-super-long-word-that-shouldn't-break-autoflow and these are some smaller words")

      editor.selectAll()
      atom.commands.dispatch editorElement, 'hard-wrap:reflow-selection'

      expect(editor.getText()).toEqual """
        this-is-a-super-long-word-that-shouldn't-break-autoflow
        and these are some smaller
        words
      """

  it "wraps based on length of entire line, not just beginning of selection"

  describe "reflowing plain text", ->
    beforeEach ->
      hardwrap = require("../lib/hard-wrap")

    fixturesBase = path.join(__dirname, "fixtures/plain-text")
    fixtureDirs = fs.readdirSync(fixturesBase)

    fixtureDirs.forEach (fixtureDir) -> it fixtureDir.replace(/-/g, ' '), ->
      fixtureBase = path.join(fixturesBase, fixtureDir)
      text = trimEnd fs.readFileSync(path.join(fixtureBase, 'in.txt'), 'utf-8')
      res = trimEnd fs.readFileSync(path.join(fixtureBase, 'out.txt'), 'utf-8')
      options = wrapColumn: 80
      try options = require("./" + path.join("fixtures/plain-text", fixtureDir, "options.json"))

      expect(hardwrap.reflow(text, options)).toEqual res

  describe "reflowing markdown", ->
    it "respects lists"
    it "inserts blockquote prefix"
