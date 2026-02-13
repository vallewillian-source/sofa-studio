// Shared JS helper (evaluated once for the module).
.pragma library

function quoteIdent(value) {
    var raw = String(value === undefined || value === null ? "" : value)
    return "\"" + raw.replace(/"/g, "\"\"") + "\""
}

function fullTable(schema, table) {
    var s = String(schema === undefined || schema === null ? "" : schema)
    var t = String(table === undefined || table === null ? "" : table)
    if (s.length === 0) {
        return quoteIdent(t)
    }
    return quoteIdent(s) + "." + quoteIdent(t)
}

function normalizeSqlExpr(value) {
    if (value === undefined || value === null) return ""
    return String(value).trim()
}

function arraysEqual(left, right) {
    if (left === right) return true
    if (!left || !right) return false
    if (left.length !== right.length) return false
    for (var i = 0; i < left.length; i++) {
        if (String(left[i]) !== String(right[i])) return false
    }
    return true
}

function replaceInArray(values, fromValue, toValue) {
    var next = []
    for (var i = 0; i < values.length; i++) {
        var v = String(values[i])
        next.push(v === String(fromValue) ? String(toValue) : v)
    }
    return next
}

function removeFromArray(values, removeValue) {
    var next = []
    for (var i = 0; i < values.length; i++) {
        var v = String(values[i])
        if (v === String(removeValue)) continue
        next.push(v)
    }
    return next
}

function ensureInArray(values, addValue) {
    var next = values.slice(0)
    var needle = String(addValue)
    for (var i = 0; i < next.length; i++) {
        if (String(next[i]) === needle) return next
    }
    next.push(needle)
    return next
}

function pkConstraintName(schema, table, explicitName) {
    var name = String(explicitName === undefined || explicitName === null ? "" : explicitName).trim()
    if (name.length > 0) return name
    return String(table) + "_pkey"
}

function buildPrimaryKeyUpdateStatements(schema, table, explicitConstraintName, oldPkColumns, nextPkColumns) {
    var stmts = []
    var tableSql = fullTable(schema, table)
    var constraint = pkConstraintName(schema, table, explicitConstraintName)

    var oldPk = oldPkColumns ? oldPkColumns.slice(0) : []
    var nextPk = nextPkColumns ? nextPkColumns.slice(0) : []

    if (oldPk.length > 0) {
        stmts.push("ALTER TABLE " + tableSql + " DROP CONSTRAINT " + quoteIdent(constraint))
    }

    if (nextPk.length > 0) {
        var cols = nextPk.map(quoteIdent).join(", ")
        stmts.push("ALTER TABLE " + tableSql + " ADD CONSTRAINT " + quoteIdent(constraint) + " PRIMARY KEY (" + cols + ")")
    }

    return stmts
}

function buildAddColumnStatements(payload) {
    var schema = payload.schema
    var table = payload.table
    var columnName = String(payload.name || "").trim()
    var columnType = String(payload.type || "").trim()
    var nullable = payload.nullable === true
    var defaultExpr = normalizeSqlExpr(payload.defaultExpr)
    var primaryKey = payload.primaryKey === true
    var existingPkColumns = payload.existingPkColumns ? payload.existingPkColumns.slice(0) : []
    var pkConstraint = payload.primaryKeyConstraintName || ""

    if (columnName.length === 0 || columnType.length === 0) return []

    var stmts = []
    var stmt = "ALTER TABLE " + fullTable(schema, table) +
        " ADD COLUMN " + quoteIdent(columnName) + " " + columnType
    if (defaultExpr.length > 0) {
        stmt += " DEFAULT " + defaultExpr
    }
    if (!nullable || primaryKey) {
        stmt += " NOT NULL"
    }
    stmts.push(stmt)

    if (primaryKey) {
        var nextPk = ensureInArray(existingPkColumns, columnName)
        stmts = stmts.concat(buildPrimaryKeyUpdateStatements(schema, table, pkConstraint, existingPkColumns, nextPk))
    }

    return stmts
}

function buildEditColumnStatements(payload) {
    var schema = payload.schema
    var table = payload.table
    var originalName = String(payload.originalName || "").trim()
    var nextName = String(payload.name || "").trim()
    var nextType = String(payload.type || "").trim()

    var originalNullable = payload.originalNullable === true
    var originalDefaultExpr = normalizeSqlExpr(payload.originalDefaultExpr)
    var originalPrimaryKey = payload.originalPrimaryKey === true

    var requestedNullable = payload.nullable === true
    var nextDefaultExpr = normalizeSqlExpr(payload.defaultExpr)
    var nextPrimaryKey = payload.primaryKey === true

    var pkConstraint = payload.primaryKeyConstraintName || ""
    var existingPkColumns = payload.existingPkColumns ? payload.existingPkColumns.slice(0) : []

    if (originalName.length === 0 || nextName.length === 0 || nextType.length === 0) return []

    var stmts = []
    var tableSql = fullTable(schema, table)

    var effectiveOriginalNullable = originalPrimaryKey ? false : originalNullable
    var effectiveNextNullable = nextPrimaryKey ? false : requestedNullable

    var workingName = originalName
    if (nextName !== originalName) {
        stmts.push("ALTER TABLE " + tableSql + " RENAME COLUMN " + quoteIdent(originalName) + " TO " + quoteIdent(nextName))
        workingName = nextName
        existingPkColumns = replaceInArray(existingPkColumns, originalName, nextName)
    }

    if (String(payload.originalType || "").trim() !== nextType) {
        stmts.push("ALTER TABLE " + tableSql + " ALTER COLUMN " + quoteIdent(workingName) + " TYPE " + nextType)
    }

    if (nextDefaultExpr !== originalDefaultExpr) {
        if (nextDefaultExpr.length === 0) {
            stmts.push("ALTER TABLE " + tableSql + " ALTER COLUMN " + quoteIdent(workingName) + " DROP DEFAULT")
        } else {
            stmts.push("ALTER TABLE " + tableSql + " ALTER COLUMN " + quoteIdent(workingName) + " SET DEFAULT " + nextDefaultExpr)
        }
    }

    if (effectiveNextNullable !== effectiveOriginalNullable) {
        stmts.push("ALTER TABLE " + tableSql + " ALTER COLUMN " + quoteIdent(workingName) + (effectiveNextNullable ? " DROP NOT NULL" : " SET NOT NULL"))
    }

    var nextPkColumns = existingPkColumns.slice(0)
    if (originalPrimaryKey && !nextPrimaryKey) {
        nextPkColumns = removeFromArray(nextPkColumns, workingName)
    }
    if (!originalPrimaryKey && nextPrimaryKey) {
        nextPkColumns = ensureInArray(nextPkColumns, workingName)
    }

    if (!arraysEqual(existingPkColumns, nextPkColumns)) {
        stmts = stmts.concat(buildPrimaryKeyUpdateStatements(schema, table, pkConstraint, existingPkColumns, nextPkColumns))
    }

    return stmts
}

function buildDropColumnStatements(payload) {
    var schema = payload.schema
    var table = payload.table
    var columnName = String(payload.columnName || "").trim()
    var isPrimaryKey = payload.isPrimaryKey === true
    var existingPkColumns = payload.existingPkColumns ? payload.existingPkColumns.slice(0) : []
    var pkConstraint = payload.primaryKeyConstraintName || ""

    if (columnName.length === 0) return []

    var stmts = []
    if (isPrimaryKey) {
        var nextPkColumns = removeFromArray(existingPkColumns, columnName)
        stmts = stmts.concat(buildPrimaryKeyUpdateStatements(schema, table, pkConstraint, existingPkColumns, nextPkColumns))
    }

    stmts.push("ALTER TABLE " + fullTable(schema, table) + " DROP COLUMN " + quoteIdent(columnName))
    return stmts
}
