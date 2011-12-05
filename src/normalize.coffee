module.exports = norm =
	clauses: (clauses, table, normalizeOp) ->
		normalized = []
		for clause in clauses
			for fld, constraint of clause
				if 'object' == typeof constraint
					for op, val of constraint
						op = normalizeOp(op)
						normalized.push field: field, op: op, value: val, table: table
				else
					normalized.push field: field, op: '=', value: constraint, table: table
		return normalized

	orderings: (orderings, table) ->
		normalized = []
		add = (field, direction) ->
			direction = switch (direction || '').toLowerCase()
				when 'asc',  'ascending'  then 'ASC'
				when 'desc', 'descending' then 'DESC'
				when '' then ''
				else throw new Error "Unsupported ordering direction #{direction}"
			normalized.push field: field, table: table, direction: direction

		for ordering in orderings
			if 'string' == typeof ordering
				[field, direction] = ordering.split /\ +/
				add field, direction
			else for field, direction of ordering
				add field, direction

		return normalized
