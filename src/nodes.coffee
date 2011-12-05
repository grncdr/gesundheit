fluid = require './fluid'
{include} = require './mixin'

class Node

class ValueNode extends Node
  constructor: (@value) ->
  copy: -> new @constructor @value

exports.NodeSet = class NodeSet extends Node
  constructor: (@nodes=[], @glue=' ') ->
  copy: (args...) ->
    c = new @constructor args...; c.nodes = copy @nodes; c
  addNode: (nodes...) -> @nodes.push nodes...

# Recurse over nested NodeSet instances, collecting parameter values
  params: ->
    params = []
    for node in @nodes
      if node.params?
        params = params.concat node.params()
      else if node.constructor == Parameter
        params.push node.value
    params

# A collection of nodes that disables the ``addNode`` method after construction.
exports.FixedNodeSet = class FixedNodeSet extends NodeSet
  constructor: (nodes, glue) ->
    super nodes, glue
    delete @addNode

exports.Binary = class Binary extends FixedNodeSet
  constructor: (@left, @op, @right) -> super [@left, @op, @right], ' '
  copy: -> new @constructor copy(@left), @op, copy(@right)

exports.ParenthesizedNodeSet = class ParenthesizedNodeSet extends NodeSet

exports.Tuple = class Tuple extends ParenthesizedNodeSet
  constructor: (nodes) -> super nodes, ', '

exports.Alias = class Alias extends Node
  constructor: (@obj, @alias) ->
  copy: -> new @constructor copy(@obj), @alias
  project: (name) -> new Projection @, name
  ref: -> @alias

Alias.getAlias = (o) ->
  if 'object' == typeof o
    keys = Object.keys(o)
    if keys.length == 1 then return keys.pop()
  return null

#######
exports.ProjectionSet = class ProjectionSet extends NodeSet
  constructor: -> super [], ', '
# Recurse over child nodes removing all Projection nodes that match the predicate
  prune: (pred) ->
    orig = @nodes
    @nodes = []
    for node of orig
      if node instanceof Projection
        if not pred node then @nodes.push node
      else if node instanceof Alias
        if not pred node.obj then @nodes.push node
  
exports.Projection = class Projection extends FixedNodeSet
  constructor: (@source, @field) -> super [@source, @field], '.'
  copy: -> new @constructor copy(@source), @field

exports.SqlFunction = class SqlFunction extends Node
  constructor: (@name, @arglist) ->
  copy: -> new @constructor @name, copy(@arglist)

exports.sqlFunction = sqlFunction = (name, args) -> new SqlFunction name, new Tuple(args)

#######
exports.RelationSet = class RelationSet extends NodeSet
  start: (@first) ->
    @byName = {}
    @nodes.unshift @first
    @byName[@first.ref()] = @active = @first
    delete @start

  registerName: (node) -> @byName[node.ref()] = node

  copy: ->
    c = super()
    if first = c.nodes.shift() then c.start first
    for node in c.nodes
      rel = node.relation || node
      c.registerName rel
    if first then c.active = c.get @active
    return c

  get: (name, strict=true) ->
    name = name.ref() unless 'string' == typeof name
    rel = @byName[name]
    if not rel and strict
      throw new Error "No such relation #{name} in #{Object.keys @byName}"
    return rel


  switch: (name) ->
    name = name.ref() unless 'string' == typeof name
    @active = @byName[name]

exports.Relation = class Relation extends ValueNode
  ref: -> @value
  project: (field) -> new Projection @, field
  field: (field) -> @project field

exports.Join = class Join extends FixedNodeSet
  constructor: (@type, @relation, @on) ->
    nodes = [@type, 'JOIN', @relation]
    if @on
      nodes.push 'ON', @on
    super nodes
  copy: -> new @constructor @type, copy(@relation), copy(@on)

#####
exports.Where = class Where extends NodeSet
  constructor: (cs) -> super cs, ' AND '

exports.Parameter = class Parameter extends ValueNode

exports.Or = class Or extends ParenthesizedNodeSet
  constructor: (cs) -> super cs, ' OR '

exports.And = class And extends ParenthesizedNodeSet
  constructor: (cs) -> super cs, ' AND '

exports.GroupBy = class GroupBy extends NodeSet
  constructor: (gs) -> super gs, ', '

exports.OrderBySet = class OrderBySet extends NodeSet
  constructor: (os) -> super os, ', '

exports.OrderBy = class OrderBy extends FixedNodeSet
  constructor: (projection, direction) -> super [projection, direction]

exports.Limit = class Limit extends ValueNode

exports.UpdateSet = class UpdateSet extends NodeSet
  constructor: (nodes) -> super nodes, ', '

exports.Returning = class Returning extends ProjectionSet

class FixedNamedNodeSet extends FixedNodeSet
  constructor: ->
    nodes = for [k, type] in @structure
      @[k] = new type
    super nodes

  copy: ->
    c = super()
    for i, [k, _] of @structure
      delete c[k]
      c[k] = c.nodes[i]
    return c
    
exports.Select = class Select extends FixedNamedNodeSet
  structure: [
    ['projections', ProjectionSet]
    ['relations',   RelationSet]
    ['where',       Where]
    ['groupBy',     GroupBy]
    ['orderBy',     OrderBySet]
    ['limit',       Limit]
  ]

  constructor: (table) -> super(); @relations.start table if table

exports.Update = class Update extends FixedNamedNodeSet
  structure: [
    ['relation',  Relation]
    ['updates',   UpdateSet]
    ['orderBy',   OrderBySet]
    ['limit',     Limit]
    ['fromList',  RelationSet] # Optional FROM portion
    ['where',     Where]
    ['returning', Returning]
  ]

  constructor: (table) ->
    console.log table
    super()
    @relation = table

exports.Insert = class Insert extends FixedNodeSet
  structure: [
    ['relation',   Relation]
    ['fromList',   RelationSet] # Optional FROM portion
    ['returning',  Returning]
  ]
  constructor: (table) ->
  copy: -> c = super()
      
exports.Delete = class Delete extends FixedNamedNodeSet
  structure: [
    ['relations', RelationSet]
    ['where',     Where]
    ['orderBy',   OrderBySet]
    ['limit',     Limit]
  ]

  constructor: (table) -> super(); @relations.start table if table

class ComparableMixin
  eq:  (other) -> new Binary @, '=',  toParam other
  gt:  (other) -> new Binary @, '>',  toParam other
  lt:  (other) -> new Binary @, '<',  toParam other
  lte: (other) -> new Binary @, '<=', toParam other
  gte: (other) -> new Binary @, '>=', toParam other
  compare: (op, other) -> new Binary @, op, toParam other

for k, v of ComparableMixin::
  Projection::[k] = v
  SqlFunction::[k] = v

exports.toParam = toParam = (it) ->
  if it instanceof Node then it
  else if Array.isArray it then new Tuple(it.map toParam)
  else new Parameter it

exports.toRelation = toRelation = (it) ->
  switch it.constructor
    when Relation, Alias then it
    when String then new Relation it
    when Object
      if alias = Alias.getAlias it
        new Alias(new Relation(it[alias]), alias)
      else
        throw new Error "Can't make relation out of #{it}"
    else
      throw new Error "Can't make relation out of #{it}"

copy = (it) ->
  if not it then return it
  switch it.constructor
    when String, Number, Boolean then it
    when Array then it.map copy
    when Object
      c = {}
      for k, v of it
        c[k] = copy v
    else
      if it.copy? then it.copy()
      else
        throw new Error "Don't know how to copy #{it}"
