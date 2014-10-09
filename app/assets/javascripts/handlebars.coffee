#
# handlebars helpers
#

getProfile = (item) ->
  if item && item.links && item.links.profile && item.links.profile.length
    if item.links.profile[0].href.match(/\/profiles\//)
      _.last(item.links.profile[0].href.split('/'))
    else if item.links.profile[0].href.match(/ef7f170b-4900-4a20-8b77-3142d4ac07ce/)
      'audio'
    else if item.links.profile[0].href.match(/5f4fe868-5065-4aa2-86e6-2387d2c7f1b6/)
      'image'
    else if item.links.profile[0].href.match(/85115aa1-df35-4324-9acd-2bb261f8a541/)
      'video'
    else
      'unknown'
  else
    'unknown'

getItemOfProfile = (item, profileType) ->
  if getProfile(item) == profileType
    item
  else
    _.find(item.items, (child) -> getProfile(child) == profileType)

getCachedTitle = (link) ->
  if PMP.cache[link.href]
    PMP.cache[link.href].attributes.title
  else
    link.title # a big "maybe"

ellipsis = (str, limit) ->
  if str.length > limit
    str = str.substr(0, limit-1)
    str = str.substring(0, str.lastIndexOf(' '))
    str + '&hellip;'
  else
    str

Handlebars.registerHelper 'proxy', (href, options) ->
  PMP.search.proxyHref(href)

Handlebars.registerHelper 'item-next', (options) ->
  if nextLink = PMP.search.findLink(this, 'next')
    options.fn(nextLink)
  else
    options.inverse(this)

Handlebars.registerHelper 'item-img', (options) ->
  if img = getItemOfProfile(this, 'image')
    options.fn(img)
  else
    options.inverse(this)

Handlebars.registerHelper 'item-alt', (options) ->
  alt = this.links.alternate
  if alt && alt.length
    options.fn(alt[0])
  else
    options.inverse(this)

Handlebars.registerHelper 'item-series', (options) ->
  best =
    if series = PMP.search.findLink(this, 'urn:collectiondoc:collection:series')
      ['Series', series.href, getCachedTitle(series)]
    else if prop = PMP.search.findLink(this, 'urn:collectiondoc:collection:property')
      ['Property', prop.href, getCachedTitle(prop)]
    else if this.links.creator && this.links.creator.length
      ['Creator', this.links.creator[0].href, getCachedTitle(this.links.creator[0])]
  if best
    options.fn(type: best[0], href: best[1], title: best[2])
  else
    options.inverse(this)

Handlebars.registerHelper 'item-types', (options) ->
  type  = getProfile(this)
  types = [type].concat _.uniq(_.map(this.items, getProfile)).sort()
  caps  = _.map types, (t) -> t.charAt(0).toUpperCase() + t.slice(1)

  # try hard to find any audio/video length
  len = false
  _.each ['audio', 'video'], (type) =>
    if item = getItemOfProfile(this, 'audio')
      _.each item.links.enclosure, (encl) ->
        if encl.meta && encl.meta.duration
          if _.isString(encl.meta.duration) && encl.meta.duration.match(/:/)
            len = encl.meta.duration
          else
            minutes = Math.floor(parseInt(encl.meta.duration) / 60)
            seconds = parseInt(encl.meta.duration) - minutes * 60
            len = "#{minutes}:#{seconds}"
  options.fn(classes: types.join(' '), label: caps.join(' + '), length: false)

Handlebars.registerHelper 'item-author', (options) ->
  if this.attributes.byline
    options.fn(name: this.attributes.byline)
  else if this.links.author && this.links.author.length
    options.fn(name: this.links.author[0].title)
  # TODO: better

Handlebars.registerHelper 'item-attachments', (options) ->
  attachs = {}
  _.each this.items, (item) ->
    type = getProfile(item)
    attachs[type] ||= []
    attachs[type].push(item)
  rets = _.map _.keys(attachs).sort(), (type) ->
    label = type.charAt(0).toUpperCase() + type.slice(1)
    if attachs[type].length != 1
      label = switch label
        when 'Story' then 'Stories'
        when 'Image' then 'Images'
        when 'Audio' then 'Audio'
        else label + 's'
    canExpand = switch type
      when 'image' then true
      else false
    options.fn(count: attachs[type].length, label: label, type: type, items: attachs[type], expandable: canExpand)
  rets.join('')

Handlebars.registerHelper 'fancy-date', (dateStr) ->
  moment(dateStr).format('MMM. D, YYYY')

Handlebars.registerHelper 'description', (attrs) ->
  if best = attrs.teaser || attrs.description || attrs.contentencoded
    new Handlebars.SafeString ellipsis(best, 400)

Handlebars.registerHelper 'img-thumb', (enclosures, options) ->
  best = _.first(enclosures).href
  _.find ['small', 'thumb', 'standard', 'primary'], (cropType) ->
    _.find enclosures, (encl) ->
      if encl && encl.meta && encl.meta.crop == cropType
        best = encl.href
  new Handlebars.SafeString(best)

Handlebars.registerHelper 'img-normal', (enclosures, options) ->
  best = _.first(enclosures).href
  _.find ['primary', 'standard'], (cropType) ->
    _.find enclosures, (encl) ->
      if encl && encl.meta && encl.meta.crop == cropType
        best = encl.href
  new Handlebars.SafeString(best)

Handlebars.registerHelper 'expander-images', (options) ->
  imgs = []
  imgs.push this if getProfile(this) == 'image'
  _.each this.items, (item) ->
    imgs.push item if getProfile(item) == 'image'
  rets = _.map imgs, (item) -> options.fn(item)
  rets.join('')