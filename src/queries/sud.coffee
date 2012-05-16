BaseQuery = require './base'
nodes = require '../nodes'
fluidize = require '../fluid'
{Or, OrderBy} = nodes

module.exports = class SUDQuery extends BaseQuery
  ###
  SUDQuery is the base class for SELECT, UPDATE, and DELETE queries. It adds
  logic to :class:`queries/base::BaseQuery` for dealing with WHERE clauses and
  ordering.
  ###

  where: (alias, predicate) ->
    ###
    Add a WHERE clause to the query. Can optionally take a table/alias name as the
    first parameter, otherwise the clause is added using the last table added to
    the query.
   
    The where clause itself is an object where each key is treated as field name
    and each value is treated as a constraint. Constraints can be literal values
    or objects, in which case each key of the constraint is treated as an
    operator, and each value must be a literal value. 
    ###
    if predicate?
      rel = @q.relations.get alias
      unknown 'table', alias unless rel?
    else
      predicate = alias
      rel = @defaultRel()

    if predicate.constructor != Object
      return @q.where.addNode predicate

    @q.where.addNode(node) for node in @makeClauses(rel, predicate)

  or: (args...) ->
    ###
    Add one or more WHERE clauses, all joined by the OR operator.
    ###
    rel = @defaultRel()
    clauses = []
    for arg in args
      clauses.push (@makeClauses rel, arg)...
    @q.where.addNode new Or clauses

  makeClauses: (rel, predicate) ->
    clauses = []
    for field, constraint of predicate
      if Object == constraint.constructor
        for op, val of constraint
          clauses.push rel.project(field).compare op, val
      else
        clauses.push rel.project(field).eq constraint
    clauses

  orderBy: (args...) ->
    ###
    Add an ORDER BY to the query. Currently this *always* uses the "active"
    table of the query. (See :meth:`queries/select::SelectQuery.from`)
   
    Each ordering can either be a string, in which case it must be a valid-ish
    SQL snippet like 'some_field DESC', (the field name and direction will still
    be normalized) or an object, in which case each key will be treated as a
    field and each value as a direction.
    ###
    rel = @defaultRel()
    orderings = []
    for orderBy in args
      switch orderBy.constructor
        when String
          orderings.push orderBy.split ' '
        when OrderBy
          @q.orderBy.addNode orderBy
        when Object
          for name, dir of orderBy
            orderings.push [name, dir]
        else
          throw new Error "Can't turn #{orderBy} into an OrderBy object"

    for [field, direction] in orderings
      direction = switch (direction || '').toLowerCase()
        when 'asc',  'ascending'  then 'ASC'
        when 'desc', 'descending' then 'DESC'
        when '' then ''
        else throw new Error "Unsupported ordering direction #{direction}"
      @q.orderBy.addNode new OrderBy(rel.project(field), direction)

  limit: (l) ->
    ### Set the LIMIT on this query ###
    @q.limit.value = l

  offset: (l) ->
    ### Set the OFFSET of this query ###
    @q.offset.value = l

  defaultRel: ->
    @q.relations.active

fluidize SUDQuery, 'where', 'or', 'limit', 'offset', 'orderBy'

# A helper for throwing Errors
unknown = (type, val) -> throw new Error "Unknown #{type}: #{val}"
