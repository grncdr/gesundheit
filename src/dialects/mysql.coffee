exports.pre =
	orderBy:
		"ORDER BY with multiple tables is only allowed for SELECT": ->
			@constructor.name == 'Select' or @relations.nodes.length == 0

	limit:
		"LIMIT with multiple tables is only allowed for SELECT": ->
			@constructor.name == 'Select' or @relations.nodes.length == 0
			
	join:
		"JOIN with ORDER BY or LIMIT is only allowed for SELECT": ->
			@constructor.name == 'Select' or (@orderBy.nodes.length == 0 and not @limit.limit)
