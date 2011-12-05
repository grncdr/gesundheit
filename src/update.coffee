fluid = require './fluid'
SUDQuery = require './sud-query'
{Update, Binary} = require './nodes'

module.exports = class UpdateQuery extends SUDQuery
	set: fluid (data) ->
		for field, value of data
	    @q.updates.addNode @q.relation.project(field).eq value

	setNodes: fluid (nodes...) -> @q.updates.push nodes...

	setRaw: fluid (data) ->
		for field, value of data
			@s.fields.push field+' = '+value

	defaultRel: -> @q.relation

UpdateQuery.table = (table, opts={}) ->
	opts.table = table
	console.log "Updating #{table}"
	new UpdateQuery Update, opts
