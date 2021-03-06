{CompositeDisposable} = require 'event-kit'
Directory = require './directory'
FileView = require './file-view'
{repoForPath} = require './helpers'

class DirectoryView extends HTMLElement
  initialize: (@directory) ->
    @subscriptions = new CompositeDisposable()
    @subscriptions.add @directory.onDidDestroy => @subscriptions.dispose()
    @subscribeToDirectory()

    @classList.add('directory', 'entry',  'list-nested-item',  'collapsed')

    @header = document.createElement('div')
    @header.classList.add('header', 'list-item')

    @directoryName = document.createElement('span')
    @directoryName.classList.add('name', 'icon')

    @entries = document.createElement('ol')
    @entries.classList.add('entries', 'list-tree')

    if @directory.symlink
      iconClass = 'icon-file-symlink-directory'
    else
      iconClass = 'icon-file-directory'
      if @directory.isRoot
        iconClass = 'icon-repo' if repoForPath(@directory.path)?.isProjectAtRoot()
      else
        iconClass = 'icon-file-submodule' if @directory.submodule
    @directoryName.classList.add(iconClass)
    @directoryName.dataset.name = @directory.name
    @directoryName.title = @directory.name
    @directoryName.dataset.path = @directory.path

    if @directory.squashedName?
      @squashedDirectoryName = document.createElement('span')
      @squashedDirectoryName.classList.add('squashed-dir')
      @squashedDirectoryName.textContent = @directory.squashedName

    directoryNameTextNode = document.createTextNode(@directory.name)

    @appendChild(@header)
    if @squashedDirectoryName?
      @directoryName.appendChild(@squashedDirectoryName)
    @directoryName.appendChild(directoryNameTextNode)
    @header.appendChild(@directoryName)
    @appendChild(@entries)

    if @directory.isRoot
      @classList.add('project-root')
    else
      @draggable = true
      @subscriptions.add @directory.onDidStatusChange => @updateStatus()
      @updateStatus()

    @expand() if @directory.expansionState.isExpanded

  updateStatus: ->
    @classList.remove('status-ignored', 'status-modified', 'status-added')
    @classList.add("status-#{@directory.status}") if @directory.status?

  subscribeToDirectory: ->
    @subscriptions.add @directory.onDidAddEntries (addedEntries) =>
      return unless @isExpanded

      numberOfEntries = @entries.children.length

      # before adding entries, check if any entries with .ts extension
      # if so, get name and check for name.js and name.js.map
      # hide these with css hidden.

      viewObj = new FileView()

      @listOfTsFiles = []

      for entry in addedEntries

        @fileExt = viewObj.getFileExt(entry)

        if viewObj.isTargetFileExt(@fileExt)
          @fileNameWithoutExt = viewObj.getFileNameWithoutExt(entry)
          #add into the list
          @listOfTsFiles.push(@fileNameWithoutExt)

      for entry in addedEntries

        view = @createViewForEntry(entry, @listOfTsFiles)

        insertionIndex = entry.indexInParentDirectory
        if insertionIndex < numberOfEntries
          @entries.insertBefore(view, @entries.children[insertionIndex])
        else
          @entries.appendChild(view)

        numberOfEntries++

  getPath: ->
    @directory.path

  isPathEqual: (pathToCompare) ->
    @directory.isPathEqual(pathToCompare)

  createViewForEntry: (entry, tsList) ->
    if entry instanceof Directory
      view = new DirectoryElement()
    else
      view = new FileView()

    view.initialize(entry, tsList)

    subscription = @directory.onDidRemoveEntries (removedEntries) ->
      for removedName, removedEntry of removedEntries when entry is removedEntry
        view.remove()
        subscription.dispose()
        break
    @subscriptions.add(subscription)

    view

  reload: ->
    @directory.reload() if @isExpanded

  toggleExpansion: (isRecursive=false) ->
    if @isExpanded then @collapse(isRecursive) else @expand(isRecursive)

  expand: (isRecursive=false) ->
    unless @isExpanded
      @isExpanded = true
      @classList.add('expanded')
      @classList.remove('collapsed')
      @directory.expand()

    if isRecursive
      for entry in @entries.children when entry instanceof DirectoryView
        entry.expand(true)

    false

  collapse: (isRecursive=false) ->
    @isExpanded = false

    if isRecursive
      for entry in @entries.children when entry.isExpanded
        entry.collapse(true)

    @classList.remove('expanded')
    @classList.add('collapsed')
    @directory.collapse()
    @entries.innerHTML = ''

DirectoryElement = document.registerElement('tree-view-directory', prototype: DirectoryView.prototype, extends: 'li')
module.exports = DirectoryElement
