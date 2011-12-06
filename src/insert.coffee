fluid = require './fluid'

BaseQuery = require './base-query'
{Insert, Tuple} = require './nodes'

# InsertQuerys are much simpler than most query types, in that they cannot 
# join multiple tables.
module.exports = class InsertQuery extends BaseQuery

	addRows: fluid (rows...) ->
		for row in rows
			@q.addRow row

	addRow: (row) -> @addRows row

	from: fluid (query) ->
		switch query.constructor
			when SelectQuery then @q.source = query.q
			when Select then @q.source = query
			else throw new Error "Can only insert from a SELECT"

InsertQuery.into = (tbl, fields, opts={}) ->
	if not fields and fields.length
		throw new Error "Column list is required when constructing an INSERT"
	opts.table = tbl
	iq = new InsertQuery Insert, opts
	# TODO this is gross
	iq.q.columns = iq.q.nodes[1] = new Tuple fields
	return iq
