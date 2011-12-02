exports.Binary = class Binary
  constructor: (@left, @op, @right) ->
  toString: -> "#{@left} #{@op} #{@right}"

exports.Grouping = class Grouping
  constructor: (@nodes=[], @glue=' ') ->
  toString: -> "#{@nodes.map((a) -> a.toString()).join @glue}"
  push: (node) -> @nodes.push(node)

exports.ParenthesizedGrouping = class ParenthesizedGrouping extends Grouping
  toString: -> "(#{super()})"

exports.Tuple = class Tuple extends ParenthesizedGrouping
  constructor: (nodes) -> super(nodes, ', ')

exports.Function = class Function
  constructor: (@name, args) -> @arglist = new Tuple(args)
  toString: -> "#{@name}#{@arglist.toString()}"

exports.Alias = class Alias
  constructor: (@obj, @alias) ->
  toString: -> "#{@obj.toString()} AS #{@alias.toString()}"
  alias: -> @alias

exports.Projection = class Projection
  constructor: (@source, @field) ->
  toString: -> "`#{@source.alias()}`.`#{@field}`"

exports.Relation = class Relation
  constructor: (@tablename) ->
  toString: -> @tablename
  alias: -> @tablename

exports.Where = class Where extends Grouping
  constructor: (cs) -> super(cs, ' AND ')
  toString: -> clause = super(); if clause then " WHERE #{super()}" else ""

exports.Comparison = class Comparison extends Binary
  constructor: (l, o, r)->
    unless /<|>|=/.exec o
      throw "Not a valid comparison operator: #{o}"
    super(l, o, r)

exports.Or = class Or extends ParenthesizedGrouping
  constructor: (cs) -> super(cs, ' OR ')

exports.And = class And extends ParenthesizedGrouping
  constructor: (cs) -> super(cs, ' AND ')

exports.RelationSet = class RelationSet extends Grouping
  constructor: (@first, joins...) -> super(joins, ' ')
  toString: ->
    if @first
      from = " FROM " + @first
      if joins = super() then from += " #{joins}"
      from
    else
      ""

exports.ProjectionSet = class ProjectionSet extends Grouping
  constructor: -> super [], ', '
  toString: -> if @nodes.length then super() else '*'

exports.Join = class Join
  constructor: (@joinType, @relation) ->
  toString: -> @joinType.toString() + ' ' + @relation.toString()

exports.Select = class Select
  constructor: (table=null)->
    @projections = new ProjectionSet()
    table = new Relation(table) if 'string' == typeof table
    @relations = new RelationSet(table) if table
    @where = new Where()
    @groupBy = ""
    @orderBy = ""
    @limit = ""

  toString: ->
    "SELECT " + @projections + @relations + @where +
      @groupBy + @orderBy + @limit

s = new Select('blah')
s.where.push(new Binary(1, '=', 1))
console.log String(s)
