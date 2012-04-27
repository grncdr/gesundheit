fluid = require '../fluid'
dialects = require '../dialects'
{toRelation} = require '../nodes'

# The base class for all queries, not very useful on it's own. The constructor
# takes a root node constructor corresponding to the query type and an options
# object. 
#
# Options:
#   table - a ``String`` or ``Relation`` or ``Alias``, or an object literal with
#     a single key and value which will be interpreted as an alias name and
#     table, respectively.
#   dialect - an object that will be used to render the AST to a SQL string.
module.exports = class BaseQuery
  constructor: (rootNodeType, opts={}) ->
    @doEcho = false
    dialectType = opts.dialect || dialects.default
    @dialect = new dialectType
    if (table = opts.table)?
      table = toRelation table

    @q = new rootNodeType table

# Dialects can specify pre-conditions that must be met before certain methods 
# can be called, these will be called in the context of the root query node with
# the original arguments
    if @dialect.pre?
      for method, checks of @dialect.pre
        for description, condition of checks
          #continue
          continue unless orig = @[method]
          do (method, description, orig, condition) =>
            @[method] = ->
              if condition.apply @q, arguments
                orig.apply @, arguments
              else
                throw new Error description

# Instantiate a new query with a deep copy of AST
  copy: ->
    c = new @constructor ->
    c.dialect = new @dialect.constructor
    c.q = @q.copy()
    return c

# Call the given function in the context of this query. Makes for a sort-of DSL
# where you can do things like:
#     
#     somequery.visit ->
#       @where x: val
#       @orderBy x: 'ASC'
# 
# The current query is also given as the first parameter to the query, in case
# you need it.
  visit: fluid (fn) ->
    fn.call @, @ if fn?

# If called before .toSql(), then resulting SQL will be sent to stdout
# via console.log()
  echo: fluid -> @doEcho = true

# Render the query to SQL using a dialect
  toSql: ->
    unless @engine
      @bind(BaseQuery.engine)

    throw new Error "Cannot render unbound query" unless @engine?.dialect

    sql = @engine.dialect.render @q
    console.log sql if @doEcho
    console.log @q.params() if @doEcho
    sql

  params: -> @q.params()

# Bind this query object to a specific engine instance
  bind: (@engine) ->

  @engine = null

# Given an object that exposes an `acquire` method, call the acquire method and 
# then continue with the result.
#
# Otherwise, call the `query` method of the object, passing it the SQL rendering
# of the query, the parameter values contained in the query, and the passed in 
# callback.
  execute: (cb) ->
    try
      sql = @toSql()
      params = @params()
    catch err
      return cb err

    unless @engine.connect
      cb new Error "Engine cannot provide a connection!"

    @engine.connect (err, conn) =>
      return cb err if err
      conn.query sql, params, (err, res) =>
        @engine.release conn if @engine.release
        return cb err if err
        cb null, res

  toString: ->
    if not @engine
      '[Unbound '+@q.constructor.name+']'
    else
      '['+@q.constructor.name+' "'+@toSql().substring(0,20)+'"]'
