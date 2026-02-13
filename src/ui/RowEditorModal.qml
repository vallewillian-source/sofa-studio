import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import sofa.ui

Popup {
    id: root
    parent: Overlay.overlay
    width: {
        if (!parent) return 760
        var maxAllowed = Math.max(420, parent.width - (Theme.spacingXLarge * 2))
        return Math.min(820, maxAllowed)
    }
    height: {
        if (!parent) return 700
        return Math.min(760, parent.height - (Theme.spacingXLarge * 2))
    }
    x: Math.round((parent.width - width) / 2)
    y: Math.max(Theme.spacingXLarge, Math.round((parent.height - height) / 2))
    padding: 0
    modal: true
    focus: true
    clip: true
    closePolicy: Popup.NoAutoClose

    property string schemaName: ""
    property string tableName: ""
    property bool submitting: false
    property string errorMessage: ""
    property color accentColor: Theme.accent
    property bool editing: false
    property var originalRowValues: []
    readonly property color notNullMarkerColor: Qt.rgba(
                                                     (Theme.error.r * 0.82) + (root.accentColor.r * 0.18),
                                                     (Theme.error.g * 0.82) + (root.accentColor.g * 0.18),
                                                     (Theme.error.b * 0.82) + (root.accentColor.b * 0.18),
                                                     1.0)
    readonly property string fullTableName: (root.schemaName.length > 0 ? root.schemaName + "." : "") + root.tableName
    readonly property int fieldCount: fieldsModel.count
    property int expandedFieldIndex: -1
    property string expandedFieldName: ""
    property string expandedFieldType: ""
    property string expandedFieldValue: ""
    property int temporalEditingFieldIndex: -1
    property string temporalEditingGroup: ""
    property string temporalDraftDate: ""
    property int temporalDraftHour: 0
    property int temporalDraftMinute: 0
    property int temporalDraftSecond: 0
    property int temporalDraftMillisecond: 0
    property var temporalOutputFormat: ({})
    property var temporalVisibleMonth: new Date()

    signal submitRequested(var entries)
    Component.onCompleted: ensureTemporalTimeModels()

    function focusFieldEditor(preferredIndex) {
        var preferred = Number(preferredIndex)
        if (isFinite(preferred) && preferred >= 0 && preferred < fieldRepeater.count) {
            var preferredItem = fieldRepeater.itemAt(preferred)
            if (preferredItem && preferredItem.focusEditor) {
                preferredItem.focusEditor()
                return
            }
        }

        for (var i = 0; i < fieldRepeater.count; i++) {
            var item = fieldRepeater.itemAt(i)
            if (item && item.focusEditor) {
                item.focusEditor()
                return
            }
        }
    }

    function openForAdd(schema, table, columns) {
        editing = false
        originalRowValues = []
        schemaName = schema || ""
        tableName = table || ""
        errorMessage = ""
        submitting = false
        fieldsModel.clear()

        for (var i = 0; i < columns.length; i++) {
            var column = columns[i]
            var columnName = ""
            var columnType = ""
            var columnDefaultValue = ""
            var columnIsNullable = true
            var columnIsPrimaryKey = false
            var columnIsMultilineInput = false
            var columnTemporalInputGroup = ""
            var columnTemporalNowExpression = ""
            if (typeof column === "string") {
                columnName = column
            } else if (column) {
                columnName = column.name || ""
                columnType = column.type || ""
                columnDefaultValue = column.defaultValue || ""
                columnIsNullable = column.isNullable !== false
                columnIsPrimaryKey = column.isPrimaryKey === true
                if (column.isMultilineInput !== undefined && column.isMultilineInput !== null) {
                    columnIsMultilineInput = column.isMultilineInput === true
                } else {
                    columnIsMultilineInput = root.isMultilineColumnType(columnType)
                }
                columnTemporalInputGroup = column.temporalInputGroup || ""
                columnTemporalNowExpression = column.temporalNowExpression || ""
            }
            if (!columnName || columnName.length === 0) {
                continue
            }
            fieldsModel.append({
                "name": columnName,
                "type": columnType,
                "defaultValue": columnDefaultValue,
                "isMultilineInput": columnIsMultilineInput,
                "temporalInputGroup": columnTemporalInputGroup,
                "temporalNowExpression": columnTemporalNowExpression,
                "notNull": !columnIsNullable,
                "isPrimaryKey": columnIsPrimaryKey,
                "initialValue": "",
                "originalRawValue": null,
                "value": ""
            })
        }

        open()
        Qt.callLater(function() {
            root.focusFieldEditor(0)
        })
    }

    function openForEdit(schema, table, columns, rowValues, preferredFocusFieldIndex) {
        editing = true
        schemaName = schema || ""
        tableName = table || ""
        errorMessage = ""
        submitting = false
        fieldsModel.clear()

        var values = rowValues || []
        originalRowValues = values.slice(0)

        for (var i = 0; i < columns.length; i++) {
            var column = columns[i]
            var columnName = ""
            var columnType = ""
            var columnDefaultValue = ""
            var columnIsNullable = true
            var columnIsPrimaryKey = false
            var columnIsMultilineInput = false
            var columnTemporalInputGroup = ""
            var columnTemporalNowExpression = ""
            if (typeof column === "string") {
                columnName = column
            } else if (column) {
                columnName = column.name || ""
                columnType = column.type || ""
                columnDefaultValue = column.defaultValue || ""
                columnIsNullable = column.isNullable !== false
                columnIsPrimaryKey = column.isPrimaryKey === true
                if (column.isMultilineInput !== undefined && column.isMultilineInput !== null) {
                    columnIsMultilineInput = column.isMultilineInput === true
                } else {
                    columnIsMultilineInput = root.isMultilineColumnType(columnType)
                }
                columnTemporalInputGroup = column.temporalInputGroup || ""
                columnTemporalNowExpression = column.temporalNowExpression || ""
            }
            if (!columnName || columnName.length === 0) {
                continue
            }

            var originalRawValue = (i < values.length) ? values[i] : null
            var displayValue = (originalRawValue === null || originalRawValue === undefined) ? "" : String(originalRawValue)

            fieldsModel.append({
                "name": columnName,
                "type": columnType,
                "defaultValue": columnDefaultValue,
                "isMultilineInput": columnIsMultilineInput,
                "temporalInputGroup": columnTemporalInputGroup,
                "temporalNowExpression": columnTemporalNowExpression,
                "notNull": !columnIsNullable,
                "isPrimaryKey": columnIsPrimaryKey,
                "initialValue": displayValue,
                "originalRawValue": originalRawValue,
                "value": displayValue
            })
        }

        open()
        Qt.callLater(function() {
            root.focusFieldEditor(preferredFocusFieldIndex)
        })
    }

    function collectEntries() {
        var entries = []
        for (var i = 0; i < fieldsModel.count; i++) {
            var row = fieldsModel.get(i)
            entries.push({
                "name": row.name,
                "value": row.value,
                "initialValue": row.initialValue,
                "originalValue": row.originalRawValue,
                "isPrimaryKey": row.isPrimaryKey === true,
                "temporalNowExpression": row.temporalNowExpression || ""
            })
        }
        return entries
    }

    function hasUnsavedChanges() {
        for (var i = 0; i < fieldsModel.count; i++) {
            var row = fieldsModel.get(i)
            var currentValue = row.value === null || row.value === undefined ? "" : String(row.value)
            var initialValue = row.initialValue === null || row.initialValue === undefined ? "" : String(row.initialValue)
            if (currentValue !== initialValue) {
                return true
            }
        }
        return false
    }

    function isMultilineColumnType(typeName) {
        var normalized = String(typeName === null || typeName === undefined ? "" : typeName).trim().toLowerCase()
        return normalized === "text" || normalized.endsWith(".text")
    }

    function temporalPlaceholder(groupName) {
        var normalized = String(groupName === null || groupName === undefined ? "" : groupName).trim().toLowerCase()
        if (normalized === "date") return "YYYY-MM-DD"
        if (normalized === "time") return "HH:MM"
        if (normalized === "datetime") return "YYYY-MM-DD HH:MM"
        return ""
    }

    function pad2(value) {
        return value < 10 ? "0" + value : "" + value
    }

    function dateKey(dateObj) {
        if (!dateObj) return ""
        var d = new Date(dateObj)
        if (isNaN(d.getTime())) return ""
        return d.getFullYear() + "-" + pad2(d.getMonth() + 1) + "-" + pad2(d.getDate())
    }

    function nowLiteralForTemporalGroup(groupName) {
        var now = new Date()
        var datePart = now.getFullYear() + "-" + pad2(now.getMonth() + 1) + "-" + pad2(now.getDate())
        var timePart = pad2(now.getHours()) + ":" + pad2(now.getMinutes())
        var normalized = String(groupName === null || groupName === undefined ? "" : groupName).trim().toLowerCase()
        if (normalized === "date") return datePart
        if (normalized === "time") return timePart
        if (normalized === "datetime") return datePart + " " + timePart
        return ""
    }

    function temporalDisplayText(currentValue, defaultValue, groupName) {
        var liveValue = currentValue === null || currentValue === undefined ? "" : String(currentValue)
        if (liveValue.length > 0) return liveValue
        var fallback = defaultValue === null || defaultValue === undefined ? "" : String(defaultValue)
        if (fallback.length > 0) return fallback
        return temporalPlaceholder(groupName)
    }

    function extractDatePart(rawValue) {
        var raw = String(rawValue === null || rawValue === undefined ? "" : rawValue)
        if (raw.length === 0) return ""

        var isoLike = raw.match(/(\d{4})[-\/](\d{2})[-\/](\d{2})/)
        if (isoLike) {
            return isoLike[1] + "-" + isoLike[2] + "-" + isoLike[3]
        }

        var brLike = raw.match(/(\d{2})\/(\d{2})\/(\d{4})/)
        if (brLike) {
            return brLike[3] + "-" + brLike[2] + "-" + brLike[1]
        }

        var parsedDate = new Date(raw)
        if (!isNaN(parsedDate.getTime())) {
            return parsedDate.getFullYear() + "-" + pad2(parsedDate.getMonth() + 1) + "-" + pad2(parsedDate.getDate())
        }
        return ""
    }

    function extractTimeParts(rawValue) {
        var raw = String(rawValue === null || rawValue === undefined ? "" : rawValue)
        if (raw.length === 0) return ({ "h": -1, "m": -1 })

        var match = raw.match(/(\d{1,2}):(\d{2})(?::(\d{2})(?:\.(\d{1,3}))?)?(?:\s*(Z|[+-]\d{2}(?::?\d{2})?))?/)
        if (!match) {
            var parsedDate = new Date(raw)
            if (!isNaN(parsedDate.getTime())) {
                return ({
                    "h": Math.max(0, Math.min(23, parsedDate.getHours())),
                    "m": Math.max(0, Math.min(59, parsedDate.getMinutes())),
                    "s": Math.max(0, Math.min(59, parsedDate.getSeconds())),
                    "ms": Math.max(0, Math.min(999, parsedDate.getMilliseconds())),
                    "tz": ""
                })
            }
            return ({ "h": -1, "m": -1 })
        }
        var secondValue = match[3] ? Math.max(0, Math.min(59, parseInt(match[3]))) : 0
        var msValue = match[4] ? Math.max(0, Math.min(999, parseInt((match[4] + "000").slice(0, 3)))) : 0
        return ({
            "h": Math.max(0, Math.min(23, parseInt(match[1]))),
            "m": Math.max(0, Math.min(59, parseInt(match[2]))),
            "s": secondValue,
            "ms": msValue,
            "tz": match[5] ? String(match[5]) : ""
        })
    }

    function detectTemporalOutputFormat(rawValue, groupName) {
        var normalized = String(groupName === null || groupName === undefined ? "" : groupName).trim().toLowerCase()
        var raw = String(rawValue === null || rawValue === undefined ? "" : rawValue)
        var fmt = {
            "dateOrder": "ymd",
            "dateSep": "-",
            "dateTimeSep": " ",
            "hasSeconds": false,
            "msDigits": 0,
            "tzSuffix": ""
        }

        var ymd = raw.match(/(\d{4})([-\/])(\d{2})\2(\d{2})/)
        if (ymd) {
            fmt.dateOrder = "ymd"
            fmt.dateSep = ymd[2]
        } else {
            var dmy = raw.match(/(\d{2})([-\/])(\d{2})\2(\d{4})/)
            if (dmy) {
                fmt.dateOrder = "dmy"
                fmt.dateSep = dmy[2]
            }
        }

        var dateTimeSepMatch = raw.match(/\d{4}[-\/]\d{2}[-\/]\d{2}(T| )\d{1,2}:\d{2}/)
        if (!dateTimeSepMatch) {
            dateTimeSepMatch = raw.match(/\d{2}[-\/]\d{2}[-\/]\d{4}(T| )\d{1,2}:\d{2}/)
        }
        if (dateTimeSepMatch) {
            fmt.dateTimeSep = dateTimeSepMatch[1]
        }

        var timeMatch = raw.match(/(\d{1,2}):(\d{2})(?::(\d{2})(?:\.(\d{1,3}))?)?(?:\s*(Z|[+-]\d{2}(?::?\d{2})?))?/)
        if (timeMatch) {
            fmt.hasSeconds = !!timeMatch[3]
            fmt.msDigits = timeMatch[4] ? String(timeMatch[4]).length : 0
            fmt.tzSuffix = timeMatch[5] ? String(timeMatch[5]) : ""
        } else if (normalized === "time" || normalized === "datetime") {
            // Fallback: try Date parsing for unknown DB-localized strings.
            var parsedDate = new Date(raw)
            if (!isNaN(parsedDate.getTime())) {
                fmt.hasSeconds = true
                fmt.msDigits = 0
                fmt.tzSuffix = ""
            }
        }

        return fmt
    }

    function composeDateLiteral(datePart, formatSpec) {
        if (!datePart || datePart.length === 0) return ""
        var parts = datePart.split("-")
        if (parts.length !== 3) return datePart
        var y = parts[0]
        var mm = parts[1]
        var dd = parts[2]
        var sep = formatSpec && formatSpec.dateSep ? formatSpec.dateSep : "-"
        var order = formatSpec && formatSpec.dateOrder ? formatSpec.dateOrder : "ymd"
        if (order === "dmy") {
            return dd + sep + mm + sep + y
        }
        return y + sep + mm + sep + dd
    }

    function composeTimeLiteral(h, m, s, ms, formatSpec) {
        var result = pad2(h) + ":" + pad2(m)
        var hasSeconds = formatSpec && formatSpec.hasSeconds
        if (hasSeconds) {
            result += ":" + pad2(s)
            var msDigits = formatSpec.msDigits ? Math.max(0, Math.min(3, Number(formatSpec.msDigits))) : 0
            if (msDigits > 0) {
                var msText = ("00" + String(Math.max(0, Math.min(999, ms)))).slice(-3)
                result += "." + msText.slice(0, msDigits)
            }
        }
        if (formatSpec && formatSpec.tzSuffix && String(formatSpec.tzSuffix).length > 0) {
            result += String(formatSpec.tzSuffix)
        }
        return result
    }

    function composeTemporalLiteral(groupName, datePart, h, m, s, ms, formatSpec) {
        var normalized = String(groupName === null || groupName === undefined ? "" : groupName).trim().toLowerCase()
        var safeDate = (datePart && datePart.length > 0) ? datePart : nowLiteralForTemporalGroup("date")
        var safeTime = composeTimeLiteral(h, m, s, ms, formatSpec)
        if (normalized === "date") return composeDateLiteral(safeDate, formatSpec)
        if (normalized === "time") return safeTime
        if (normalized === "datetime") {
            var dtSep = (formatSpec && formatSpec.dateTimeSep) ? formatSpec.dateTimeSep : " "
            return composeDateLiteral(safeDate, formatSpec) + dtSep + safeTime
        }
        return ""
    }

    function parseTemporalSeedValue(rawValue, groupName) {
        var normalized = String(groupName === null || groupName === undefined ? "" : groupName).trim().toLowerCase()
        var datePart = extractDatePart(rawValue)
        var time = extractTimeParts(rawValue)
        var validDate = datePart.length > 0
        var validTime = time.h >= 0 && time.m >= 0
        return {
            "group": normalized,
            "date": validDate ? datePart : "",
            "hour": validTime ? time.h : -1,
            "minute": validTime ? time.m : -1,
            "second": validTime ? time.s : 0,
            "millisecond": validTime ? time.ms : 0,
            "timeZoneSuffix": validTime && time.tz ? String(time.tz) : "",
            "valid": normalized === "date"
                     ? validDate
                     : (normalized === "time"
                        ? validTime
                        : (validDate && validTime))
        }
    }

    function openTemporalEditor(fieldIndex, groupName, currentValue, defaultValue) {
        if (fieldIndex < 0 || fieldIndex >= fieldsModel.count) return
        ensureTemporalTimeModels()

        var normalized = String(groupName === null || groupName === undefined ? "" : groupName).trim().toLowerCase()
        if (normalized !== "date" && normalized !== "time" && normalized !== "datetime") return

        var seedValue = currentValue === null || currentValue === undefined ? "" : String(currentValue)
        if (seedValue.length === 0) {
            seedValue = defaultValue === null || defaultValue === undefined ? "" : String(defaultValue)
        }

        var parsed = parseTemporalSeedValue(seedValue, normalized)
        var outputFmt = detectTemporalOutputFormat(seedValue, normalized)
        if (parsed.timeZoneSuffix && parsed.timeZoneSuffix.length > 0) {
            outputFmt.tzSuffix = parsed.timeZoneSuffix
        }
        var fallbackNow = new Date()

        temporalEditingFieldIndex = fieldIndex
        temporalEditingGroup = normalized
        temporalOutputFormat = outputFmt
        temporalDraftDate = parsed.valid && parsed.date.length > 0
            ? parsed.date
            : nowLiteralForTemporalGroup("date")
        temporalDraftHour = parsed.valid && parsed.hour >= 0
            ? parsed.hour
            : fallbackNow.getHours()
        temporalDraftMinute = parsed.valid && parsed.minute >= 0
            ? parsed.minute
            : fallbackNow.getMinutes()
        temporalDraftSecond = parsed.valid ? parsed.second : fallbackNow.getSeconds()
        temporalDraftMillisecond = parsed.valid ? parsed.millisecond : fallbackNow.getMilliseconds()
        var monthSeed = new Date(temporalDraftDate + "T00:00:00")
        if (isNaN(monthSeed.getTime())) {
            monthSeed = fallbackNow
        }
        temporalVisibleMonth = new Date(monthSeed.getFullYear(), monthSeed.getMonth(), 1)
        temporalEditorPopup.open()
    }

    function applyTemporalSubmit() {
        if (temporalEditingFieldIndex < 0 || temporalEditingFieldIndex >= fieldsModel.count) {
            temporalEditorPopup.close()
            return
        }
        var finalValue = composeTemporalLiteral(
                             temporalEditingGroup,
                             temporalDraftDate,
                             temporalDraftHour,
                             temporalDraftMinute,
                             temporalDraftSecond,
                             temporalDraftMillisecond,
                             temporalOutputFormat)
        fieldsModel.setProperty(temporalEditingFieldIndex, "value", finalValue)
        temporalEditorPopup.close()
    }

    function applyTemporalNow() {
        if (temporalEditingFieldIndex < 0 || temporalEditingFieldIndex >= fieldsModel.count) {
            temporalEditorPopup.close()
            return
        }
        var now = new Date()
        var datePart = now.getFullYear() + "-" + pad2(now.getMonth() + 1) + "-" + pad2(now.getDate())
        var nowValue = composeTemporalLiteral(
                           temporalEditingGroup,
                           datePart,
                           now.getHours(),
                           now.getMinutes(),
                           now.getSeconds(),
                           now.getMilliseconds(),
                           temporalOutputFormat)
        fieldsModel.setProperty(temporalEditingFieldIndex, "value", nowValue)
        temporalEditorPopup.close()
    }

    function setTemporalDraftDate(dateObj) {
        if (!dateObj) return
        var key = dateKey(dateObj)
        if (!key || key.length === 0) return
        temporalDraftDate = key
    }

    function ensureTemporalTimeModels() {
        if (temporalHourModel.count === 0) {
            for (var hour = 0; hour < 24; hour++) {
                temporalHourModel.append({
                    "label": pad2(hour),
                    "value": hour
                })
            }
        }
        if (temporalMinuteModel.count === 0) {
            for (var minute = 0; minute < 60; minute++) {
                temporalMinuteModel.append({
                    "label": pad2(minute),
                    "value": minute
                })
            }
        }
    }

    function openExpandedTextEditor(fieldIndex) {
        if (fieldIndex < 0 || fieldIndex >= fieldsModel.count) return
        var row = fieldsModel.get(fieldIndex)
        expandedFieldIndex = fieldIndex
        expandedFieldName = row.name || ""
        expandedFieldType = row.type || ""
        expandedFieldValue = row.value === null || row.value === undefined ? "" : String(row.value)
        expandedTextInput.text = expandedFieldValue
        expandedTextPopup.open()
        Qt.callLater(function() {
            expandedTextInput.forceActiveFocus()
            expandedTextInput.cursorPosition = expandedTextInput.text.length
        })
    }

    function applyExpandedTextEditor() {
        if (expandedFieldIndex < 0 || expandedFieldIndex >= fieldsModel.count) {
            expandedTextPopup.close()
            return
        }
        fieldsModel.setProperty(expandedFieldIndex, "value", expandedTextInput.text)
        expandedFieldValue = expandedTextInput.text
        expandedTextPopup.close()
    }

    function clearAllValues() {
        for (var i = 0; i < fieldsModel.count; i++) {
            if (editing) {
                var row = fieldsModel.get(i)
                var initialValue = row.initialValue === null || row.initialValue === undefined ? "" : String(row.initialValue)
                fieldsModel.setProperty(i, "value", initialValue)
            } else {
                fieldsModel.setProperty(i, "value", "")
            }
        }
    }

    function quoteIdentifier(name) {
        return "\"" + String(name).replace(/"/g, "\"\"") + "\""
    }

    function quoteSqlStringLiteral(value) {
        return "'" + String(value).replace(/'/g, "''") + "'"
    }

    function buildPreviewSql() {
        if (!tableName || tableName.length === 0) return ""

        var target = schemaName && schemaName.length > 0
            ? quoteIdentifier(schemaName) + "." + quoteIdentifier(tableName)
            : quoteIdentifier(tableName)

        if (editing) {
            var assignments = []
            var conditions = []
            var pkConditions = []
            for (var e = 0; e < fieldsModel.count; e++) {
                var editRow = fieldsModel.get(e)
                var valueText = String(editRow.value === null || editRow.value === undefined ? "" : editRow.value)
                var trimmedEdit = valueText.trim()
                var initialText = String(editRow.initialValue === null || editRow.initialValue === undefined ? "" : editRow.initialValue)
                var quotedName = quoteIdentifier(editRow.name)

                if (valueText !== initialText) {
                    if (trimmedEdit.toUpperCase() === "NULL") {
                        assignments.push(quotedName + " = NULL")
                    } else {
                        assignments.push(quotedName + " = " + quoteSqlStringLiteral(valueText))
                    }
                }

                var originalValue = editRow.originalRawValue
                if (originalValue === null || originalValue === undefined) {
                    conditions.push(quotedName + " IS NULL")
                    if (editRow.isPrimaryKey === true) {
                        pkConditions.push(quotedName + " IS NULL")
                    }
                } else if (typeof originalValue === "number") {
                    conditions.push(quotedName + " = " + String(originalValue))
                    if (editRow.isPrimaryKey === true) {
                        pkConditions.push(quotedName + " = " + String(originalValue))
                    }
                } else if (typeof originalValue === "boolean") {
                    conditions.push(quotedName + " = " + (originalValue ? "TRUE" : "FALSE"))
                    if (editRow.isPrimaryKey === true) {
                        pkConditions.push(quotedName + " = " + (originalValue ? "TRUE" : "FALSE"))
                    }
                } else {
                    var quotedOriginal = quoteSqlStringLiteral(String(originalValue))
                    conditions.push(quotedName + " = " + quotedOriginal)
                    if (editRow.isPrimaryKey === true) {
                        pkConditions.push(quotedName + " = " + quotedOriginal)
                    }
                }
            }

            if (assignments.length === 0) {
                return "-- No changes detected."
            }
            var finalConditions = pkConditions.length > 0 ? pkConditions : conditions
            if (finalConditions.length === 0) {
                return ""
            }
            return "UPDATE " + target + " SET " + assignments.join(", ") + " WHERE " + finalConditions.join(" AND ") + ";"
        }

        var quotedCols = []
        var quotedVals = []
        for (var i = 0; i < fieldsModel.count; i++) {
            var row = fieldsModel.get(i)
            var rawValue = row.value
            if (rawValue === null || rawValue === undefined) continue

            var rawText = String(rawValue)
            var trimmed = rawText.trim()
            if (trimmed.length === 0) continue

            quotedCols.push(quoteIdentifier(row.name))
            if (trimmed.toUpperCase() === "NULL") {
                quotedVals.push("NULL")
            } else {
                quotedVals.push(quoteSqlStringLiteral(rawText))
            }
        }

        if (quotedCols.length === 0) {
            return "INSERT INTO " + target + " DEFAULT VALUES;"
        }
        return "INSERT INTO " + target + " (" + quotedCols.join(", ") + ") VALUES (" + quotedVals.join(", ") + ");"
    }

    function requestSubmit() {
        if (root.submitting) return
        root.errorMessage = ""
        root.submitRequested(root.collectEntries())
    }

    function requestCloseConfirmation() {
        if (root.submitting) return
        if (!root.hasUnsavedChanges()) {
            root.close()
            return
        }
        closeConfirmPopup.open()
    }

    function confirmAndClose() {
        closeConfirmPopup.close()
        root.close()
    }

    Keys.onPressed: function(event) {
        if ((event.modifiers & Qt.ControlModifier)
                && (event.key === Qt.Key_Return || event.key === Qt.Key_Enter)) {
            event.accepted = true
            root.requestSubmit()
        }
    }

    background: Rectangle {
        color: Theme.surface
        border.color: Theme.border
        border.width: 1
        radius: 10
    }

    ListModel {
        id: fieldsModel
        dynamicRoles: true
    }

    ListModel {
        id: temporalHourModel
    }

    ListModel {
        id: temporalMinuteModel
    }

    contentItem: ColumnLayout {
        anchors.fill: parent
        spacing: 0

        Rectangle {
            Layout.fillWidth: true
            color: Theme.surfaceHighlight
            border.color: Theme.border
            border.width: 1
            implicitHeight: headerContent.implicitHeight + (Theme.spacingLarge * 2)

            ColumnLayout {
                id: headerContent
                anchors.fill: parent
                anchors.margins: Theme.spacingLarge
                spacing: Theme.spacingMedium

                RowLayout {
                    Layout.fillWidth: true
                    spacing: Theme.spacingMedium

                    Rectangle {
                        Layout.preferredWidth: 30
                        Layout.preferredHeight: 30
                        radius: 15
                        color: Qt.rgba(root.accentColor.r, root.accentColor.g, root.accentColor.b, 0.2)
                        border.color: Qt.rgba(root.accentColor.r, root.accentColor.g, root.accentColor.b, 0.45)
                        border.width: 1

                        Text {
                            anchors.centerIn: parent
                            text: "+"
                            color: root.accentColor
                            font.bold: true
                            font.pixelSize: 16
                        }
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 2

                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 0

                            Text {
                                text: root.editing ? "Edit Row to " : "Add Row to "
                                color: Theme.textPrimary
                                font.pixelSize: 20
                                font.bold: true
                            }

                            Text {
                                text: root.schemaName.length > 0 ? root.schemaName : "default"
                                color: Theme.textSecondary
                                font.pixelSize: 20
                                font.bold: true
                            }

                            Text {
                                text: "."
                                color: Theme.textSecondary
                                font.pixelSize: 20
                                font.bold: true
                            }

                            Text {
                                Layout.fillWidth: true
                                text: root.tableName
                                color: root.accentColor
                                font.pixelSize: 20
                                font.bold: true
                                elide: Text.ElideMiddle
                            }
                        }

                        Text {
                            Layout.fillWidth: true
                            text: root.editing
                                  ? "Adjust values and save the row changes."
                                  : "Fill in the values to insert a new row."
                            color: Theme.textSecondary
                            font.pixelSize: 12
                            wrapMode: Text.WordWrap
                        }
                    }

                    AppButton {
                        text: "Close"
                        isPrimary: false
                        enabled: !root.submitting
                        onClicked: root.requestCloseConfirmation()
                    }
                }

            }
        }

        ScrollView {
            id: bodyScroll
            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true
            contentWidth: availableWidth
            ScrollBar.horizontal.policy: ScrollBar.AlwaysOff

            Item {
                width: Math.max(bodyScroll.availableWidth, 1)
                implicitHeight: bodyContent.implicitHeight + (Theme.spacingLarge * 2)

                ColumnLayout {
                    id: bodyContent
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.top: parent.top
                    anchors.leftMargin: Theme.spacingLarge
                    anchors.rightMargin: Theme.spacingLarge
                    anchors.topMargin: Theme.spacingLarge
                    spacing: Theme.spacingLarge

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: Theme.spacingSmall

                        Text {
                            Layout.fillWidth: true
                            text: "SQL preview"
                            color: Theme.textPrimary
                            font.pixelSize: 12
                            font.bold: true
                        }

                        TextArea {
                            id: previewSqlText
                            Layout.fillWidth: true
                            readOnly: true
                            selectByMouse: true
                            wrapMode: TextEdit.WrapAnywhere
                            leftPadding: 0
                            rightPadding: 0
                            topPadding: 0
                            bottomPadding: 0
                            text: root.buildPreviewSql()
                            color: Theme.textPrimary
                            selectionColor: Theme.accent
                            selectedTextColor: "#FFFFFF"
                            background: Rectangle { color: "transparent" }
                            font.pixelSize: 11
                            font.family: Qt.platform.os === "osx" ? "Menlo" : "Monospace"
                            implicitHeight: Math.max(40, contentHeight)
                        }

                        SqlSyntaxHighlighter {
                            document: previewSqlText.textDocument
                            keywordColor: Theme.accentSecondary
                            stringColor: Theme.tintColor(Theme.textPrimary, Theme.connectionAvatarColors[3], 0.55)
                            numberColor: Theme.tintColor(Theme.textPrimary, Theme.connectionAvatarColors[8], 0.65)
                            commentColor: Theme.textSecondary
                        }
                    }

                    GridLayout {
                        id: fieldsGrid
                        Layout.fillWidth: true
                        columns: root.width >= 760 ? 2 : 1
                        columnSpacing: Theme.spacingMedium
                        rowSpacing: Theme.spacingMedium

                        Repeater {
                            id: fieldRepeater
                            model: fieldsModel

                            Rectangle {
                                id: fieldCard
                                Layout.fillWidth: true
                                Layout.alignment: Qt.AlignTop
                                Layout.preferredWidth: fieldsGrid.columns > 1
                                    ? (fieldsGrid.width - fieldsGrid.columnSpacing) / 2
                                    : fieldsGrid.width
                                radius: Theme.radius
                                color: Theme.surface
                                border.width: 0
                                implicitHeight: fieldCardContent.implicitHeight + (Theme.spacingMedium * 2)
                                readonly property string temporalGroup: String(model.temporalInputGroup || "").trim().toLowerCase()
                                readonly property bool useTemporalEditor: temporalGroup.length > 0
                                readonly property bool useMultilineEditor: model.isMultilineInput === true
                                readonly property bool temporalShowsPlaceholder:
                                    String(model.value === null || model.value === undefined ? "" : model.value).length === 0
                                    && String(model.defaultValue === null || model.defaultValue === undefined ? "" : model.defaultValue).length === 0

                                function focusEditor() {
                                    if (fieldCard.useTemporalEditor) {
                                        temporalFieldMouseArea.forceActiveFocus()
                                    } else if (singleLineInput.visible) {
                                        singleLineInput.forceActiveFocus()
                                    } else if (multiLineInput.visible) {
                                        multiLineInput.forceActiveFocus()
                                    }
                                }

                                ColumnLayout {
                                    id: fieldCardContent
                                    anchors.fill: parent
                                    anchors.margins: Theme.spacingMedium
                                    spacing: Theme.spacingSmall

                                    RowLayout {
                                        id: fieldMetaRow
                                        Layout.fillWidth: true
                                        spacing: Theme.spacingSmall

                                        Text {
                                            id: notNullMarker
                                            Layout.alignment: Qt.AlignVCenter
                                            text: "*"
                                            visible: model.notNull === true
                                            color: root.notNullMarkerColor
                                            font.pixelSize: 13
                                            font.bold: true
                                        }

                                        Text {
                                            id: fieldNameLabel
                                            Layout.preferredWidth: Math.min(
                                                                       fieldNameLabel.implicitWidth,
                                                                       Math.max(
                                                                           0,
                                                                           fieldMetaRow.width
                                                                           - (notNullMarker.visible
                                                                                ? (notNullMarker.implicitWidth + fieldMetaRow.spacing)
                                                                                : 0)
                                                                           - (fieldTypeLabel.visible
                                                                                ? (fieldTypeLabel.implicitWidth + fieldMetaRow.spacing)
                                                                                : 0)))
                                            text: model.name
                                            color: Theme.textPrimary
                                            font.pixelSize: 14
                                            font.bold: true
                                            elide: Text.ElideRight
                                        }

                                        Text {
                                            id: fieldTypeLabel
                                            Layout.alignment: Qt.AlignVCenter
                                            text: model.type || ""
                                            visible: text.length > 0
                                            color: Theme.textSecondary
                                            font.pixelSize: 11
                                            font.bold: false
                                        }
                                    }

                                    Rectangle {
                                        id: temporalFieldBox
                                        Layout.fillWidth: true
                                        visible: fieldCard.useTemporalEditor
                                        implicitHeight: 36
                                        color: Theme.surface
                                        border.color: temporalFieldMouseArea.containsMouse
                                            || temporalFieldMouseArea.activeFocus
                                            || temporalCalendarMouseArea.containsMouse
                                            ? root.accentColor
                                            : Theme.border
                                        border.width: 1
                                        radius: Theme.radius

                                        RowLayout {
                                            z: 1
                                            anchors.fill: parent
                                            anchors.leftMargin: 10
                                            anchors.rightMargin: 10
                                            spacing: Theme.spacingSmall

                                            Text {
                                                Layout.fillWidth: true
                                                text: root.temporalDisplayText(model.value, model.defaultValue, fieldCard.temporalGroup)
                                                color: fieldCard.temporalShowsPlaceholder ? Theme.textSecondary : Theme.textPrimary
                                                font.pixelSize: 13
                                                elide: Text.ElideRight
                                                verticalAlignment: Text.AlignVCenter
                                            }

                                            Rectangle {
                                                id: temporalCalendarButton
                                                Layout.preferredWidth: 66
                                                Layout.preferredHeight: 22
                                                radius: 5
                                                color: Qt.rgba(Theme.textSecondary.r, Theme.textSecondary.g, Theme.textSecondary.b, 0.08)
                                                border.width: 1
                                                border.color: Theme.border

                                                Text {
                                                    anchors.centerIn: parent
                                                    text: "calendar"
                                                    color: Theme.textSecondary
                                                    font.pixelSize: 10
                                                    font.bold: true
                                                }

                                                MouseArea {
                                                    id: temporalCalendarMouseArea
                                                    anchors.fill: parent
                                                    hoverEnabled: true
                                                    enabled: !root.submitting
                                                    cursorShape: Qt.PointingHandCursor
                                                    onClicked: root.openTemporalEditor(index, fieldCard.temporalGroup, model.value, model.defaultValue)
                                                }
                                            }
                                        }

                                        MouseArea {
                                            id: temporalFieldMouseArea
                                            z: 0
                                            anchors.fill: parent
                                            hoverEnabled: true
                                            enabled: !root.submitting
                                            cursorShape: Qt.PointingHandCursor
                                            onClicked: root.openTemporalEditor(index, fieldCard.temporalGroup, model.value, model.defaultValue)
                                        }
                                    }

                                    AppTextField {
                                        id: singleLineInput
                                        Layout.fillWidth: true
                                        visible: !fieldCard.useMultilineEditor && !fieldCard.useTemporalEditor
                                        accentColor: root.accentColor
                                        enabled: !root.submitting
                                        placeholderText: model.defaultValue || ""
                                        text: model.value
                                        onTextChanged: {
                                            fieldsModel.setProperty(index, "value", text)
                                        }
                                    }

                                    Rectangle {
                                        id: multiLineFieldBox
                                        Layout.fillWidth: true
                                        visible: fieldCard.useMultilineEditor && !fieldCard.useTemporalEditor
                                        implicitHeight: 110
                                        color: Theme.surface
                                        border.color: multiLineInput.activeFocus ? root.accentColor : Theme.border
                                        border.width: 1
                                        radius: Theme.radius

                                        TextArea {
                                            id: multiLineInput
                                            anchors.fill: parent
                                            anchors.margins: 1
                                            anchors.rightMargin: 28
                                            enabled: !root.submitting
                                            text: model.value
                                            placeholderText: model.defaultValue || ""
                                            color: Theme.textPrimary
                                            selectByMouse: true
                                            wrapMode: TextEdit.Wrap
                                            leftPadding: 10
                                            rightPadding: 8
                                            topPadding: 8
                                            bottomPadding: 8
                                            selectionColor: root.accentColor
                                            selectedTextColor: "#FFFFFF"
                                            font.pixelSize: 13
                                            background: Rectangle { color: "transparent" }
                                            onTextChanged: {
                                                fieldsModel.setProperty(index, "value", text)
                                            }
                                        }

                                        Rectangle {
                                            id: expandButton
                                            width: 20
                                            height: 20
                                            radius: 5
                                            anchors.top: parent.top
                                            anchors.right: parent.right
                                            anchors.topMargin: 6
                                            anchors.rightMargin: 6
                                            color: expandMouseArea.containsMouse
                                                ? Qt.rgba(root.accentColor.r, root.accentColor.g, root.accentColor.b, 0.16)
                                                : Qt.rgba(Theme.textSecondary.r, Theme.textSecondary.g, Theme.textSecondary.b, 0.08)
                                            border.width: 1
                                            border.color: expandMouseArea.containsMouse
                                                ? Qt.rgba(root.accentColor.r, root.accentColor.g, root.accentColor.b, 0.45)
                                                : Theme.border

                                            Canvas {
                                                id: expandIconCanvas
                                                anchors.fill: parent
                                                anchors.margins: 4
                                                onPaint: {
                                                    var ctx = getContext("2d")
                                                    ctx.clearRect(0, 0, width, height)
                                                    ctx.lineWidth = 1.4
                                                    ctx.strokeStyle = expandMouseArea.containsMouse ? root.accentColor : Theme.textSecondary
                                                    ctx.lineCap = "round"
                                                    ctx.lineJoin = "round"

                                                    ctx.beginPath()
                                                    ctx.moveTo(2, 6)
                                                    ctx.lineTo(2, 2)
                                                    ctx.lineTo(6, 2)
                                                    ctx.moveTo(8, 12)
                                                    ctx.lineTo(12, 12)
                                                    ctx.lineTo(12, 8)
                                                    ctx.moveTo(2, 2)
                                                    ctx.lineTo(6, 6)
                                                    ctx.moveTo(12, 12)
                                                    ctx.lineTo(8, 8)
                                                    ctx.stroke()
                                                }
                                            }

                                            MouseArea {
                                                id: expandMouseArea
                                                anchors.fill: parent
                                                hoverEnabled: true
                                                enabled: !root.submitting
                                                cursorShape: Qt.PointingHandCursor
                                                onEntered: expandIconCanvas.requestPaint()
                                                onExited: expandIconCanvas.requestPaint()
                                                onClicked: root.openExpandedTextEditor(index)
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }

                    Item {
                        Layout.fillWidth: true
                        Layout.preferredHeight: Theme.spacingSmall
                    }
                }
            }
        }

        Rectangle {
            Layout.fillWidth: true
            color: Theme.surface
            border.color: Theme.border
            border.width: 1
            implicitHeight: footerContent.implicitHeight + (Theme.spacingLarge * 2)

            ColumnLayout {
                id: footerContent
                anchors.fill: parent
                anchors.margins: Theme.spacingLarge
                spacing: Theme.spacingMedium

                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: root.errorMessage.length > 0 ? errorText.implicitHeight + (Theme.spacingMedium * 2) : 0
                    visible: root.errorMessage.length > 0
                    radius: Theme.radius
                    color: Qt.rgba(Theme.error.r, Theme.error.g, Theme.error.b, 0.12)
                    border.color: Qt.rgba(Theme.error.r, Theme.error.g, Theme.error.b, 0.38)
                    border.width: 1

                    Text {
                        id: errorText
                        anchors.fill: parent
                        anchors.margins: Theme.spacingMedium
                        wrapMode: Text.WordWrap
                        text: root.errorMessage
                        color: Theme.error
                        font.pixelSize: 12
                    }
                }

                RowLayout {
                    Layout.fillWidth: true
                    spacing: Theme.spacingMedium

                    AppButton {
                        text: "Clear Values"
                        isOutline: true
                        accentColor: root.accentColor
                        enabled: !root.submitting && root.fieldCount > 0
                        onClicked: root.clearAllValues()
                    }

                    Text {
                        Layout.fillWidth: true
                        text: "Tip: Use Ctrl+Enter to submit quickly."
                        color: Theme.textSecondary
                        font.pixelSize: 11
                        elide: Text.ElideRight
                    }

                    AppButton {
                        text: "Cancel"
                        isPrimary: false
                        enabled: !root.submitting
                        onClicked: root.requestCloseConfirmation()
                    }

                    AppButton {
                        text: root.submitting
                              ? (root.editing ? "Saving..." : "Inserting...")
                              : (root.editing ? "Save Changes" : "Insert Row")
                        isPrimary: true
                        accentColor: root.accentColor
                        enabled: !root.submitting
                        onClicked: root.requestSubmit()
                    }
                }
            }
        }
    }

    Popup {
        id: temporalEditorPopup
        parent: Overlay.overlay
        modal: true
        focus: true
        closePolicy: Popup.NoAutoClose
        width: {
            if (!parent) return 420
            var preferred = temporalEditorContent.showDateControls ? 420 : 360
            return Math.min(preferred, Math.max(320, parent.width - (Theme.spacingXLarge * 2)))
        }
        x: Math.round((parent.width - width) / 2)
        y: Math.round((parent.height - height) / 2)
        padding: Theme.spacingLarge
        implicitHeight: temporalEditorContent.implicitHeight + topPadding + bottomPadding
        onClosed: {
            root.temporalEditingFieldIndex = -1
            root.temporalEditingGroup = ""
            root.temporalOutputFormat = ({})
        }

        background: Rectangle {
            color: Theme.surface
            border.color: Theme.border
            border.width: 1
            radius: 10
        }

        contentItem: ColumnLayout {
            id: temporalEditorContent
            width: temporalEditorPopup.availableWidth
            spacing: Theme.spacingMedium
            readonly property bool showDateControls:
                root.temporalEditingGroup === "date" || root.temporalEditingGroup === "datetime"
            readonly property bool showTimeControls:
                root.temporalEditingGroup === "time" || root.temporalEditingGroup === "datetime"

            Text {
                Layout.fillWidth: true
                text: root.temporalEditingGroup === "date"
                    ? "Select date"
                    : (root.temporalEditingGroup === "time" ? "Select time" : "Select date and time")
                color: Theme.textPrimary
                font.pixelSize: 15
                font.bold: true
            }

            ColumnLayout {
                Layout.fillWidth: true
                visible: temporalEditorContent.showDateControls
                spacing: Theme.spacingSmall

                RowLayout {
                    Layout.fillWidth: true
                    spacing: Theme.spacingSmall

                    AppButton {
                        text: "<"
                        isOutline: true
                        accentColor: root.accentColor
                        Layout.preferredHeight: 24
                        Layout.preferredWidth: 28
                        onClicked: {
                            var prevMonth = new Date(root.temporalVisibleMonth)
                            prevMonth.setMonth(prevMonth.getMonth() - 1)
                            root.temporalVisibleMonth = new Date(prevMonth.getFullYear(), prevMonth.getMonth(), 1)
                        }
                    }

                    Text {
                        Layout.fillWidth: true
                        text: Qt.formatDate(root.temporalVisibleMonth, "MMMM yyyy")
                        color: Theme.textPrimary
                        font.pixelSize: 13
                        font.bold: true
                        horizontalAlignment: Text.AlignHCenter
                    }

                    AppButton {
                        text: ">"
                        isOutline: true
                        accentColor: root.accentColor
                        Layout.preferredHeight: 24
                        Layout.preferredWidth: 28
                        onClicked: {
                            var nextMonth = new Date(root.temporalVisibleMonth)
                            nextMonth.setMonth(nextMonth.getMonth() + 1)
                            root.temporalVisibleMonth = new Date(nextMonth.getFullYear(), nextMonth.getMonth(), 1)
                        }
                    }
                }

                DayOfWeekRow {
                    Layout.fillWidth: true
                    locale: Qt.locale()
                    delegate: Text {
                        required property var model
                        text: model.shortName
                        color: Theme.textSecondary
                        font.pixelSize: 11
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                    }
                }

                MonthGrid {
                    id: temporalMonthGrid
                    Layout.fillWidth: true
                    month: root.temporalVisibleMonth.getMonth()
                    year: root.temporalVisibleMonth.getFullYear()
                    locale: Qt.locale()

                    delegate: Rectangle {
                        required property var model
                        required property var date
                        width: 36
                        height: 30
                        radius: 6
                        color: root.dateKey(date) === root.temporalDraftDate
                            ? Qt.rgba(root.accentColor.r, root.accentColor.g, root.accentColor.b, 0.22)
                            : "transparent"
                        border.width: root.dateKey(date) === root.temporalDraftDate ? 1 : 0
                        border.color: Qt.rgba(root.accentColor.r, root.accentColor.g, root.accentColor.b, 0.55)

                        Text {
                            anchors.centerIn: parent
                            text: model.day
                            color: date.getMonth() === temporalMonthGrid.month ? Theme.textPrimary : Theme.textSecondary
                            font.pixelSize: 12
                            opacity: date.getMonth() === temporalMonthGrid.month ? 1.0 : 0.45
                        }

                        MouseArea {
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.setTemporalDraftDate(date)
                        }
                    }
                }
            }

            ColumnLayout {
                Layout.fillWidth: true
                visible: temporalEditorContent.showTimeControls
                spacing: Theme.spacingSmall

                Text {
                    Layout.fillWidth: true
                    text: "Time"
                    color: Theme.textSecondary
                    font.pixelSize: 11
                    font.bold: true
                    opacity: 0.9
                }

                RowLayout {
                    Layout.fillWidth: true
                    spacing: Theme.spacingSmall

                    ComboBox {
                        id: hourComboBox
                        Layout.fillWidth: true
                        Layout.preferredHeight: Theme.buttonHeight
                        textRole: "label"
                        valueRole: "value"
                        model: temporalHourModel
                        currentIndex: Math.max(0, Math.min(temporalHourModel.count - 1, root.temporalDraftHour))
                        onCurrentIndexChanged: {
                            if (currentIndex >= 0 && currentIndex < temporalHourModel.count) {
                                root.temporalDraftHour = Number(temporalHourModel.get(currentIndex).value)
                            }
                        }

                        background: Rectangle {
                            implicitHeight: Theme.buttonHeight
                            color: Theme.surface
                            border.color: parent.activeFocus ? root.accentColor : Theme.border
                            border.width: 1
                            radius: Theme.radius
                        }

                        contentItem: Text {
                            leftPadding: 10
                            rightPadding: 10
                            text: hourComboBox.displayText
                            color: Theme.textPrimary
                            font.pixelSize: 13
                            verticalAlignment: Text.AlignVCenter
                            elide: Text.ElideRight
                        }

                        delegate: ItemDelegate {
                            required property string label
                            required property int index
                            width: hourComboBox.width
                            height: 30
                            contentItem: Text {
                                text: label
                                color: Theme.textPrimary
                                font.pixelSize: 13
                                elide: Text.ElideRight
                                verticalAlignment: Text.AlignVCenter
                                opacity: 1.0
                            }
                            background: Rectangle {
                                color: highlighted ? Theme.surfaceHighlight : Theme.surface
                            }
                            highlighted: hourComboBox.highlightedIndex === index
                        }

                        popup: Popup {
                            y: hourComboBox.height - 1
                            width: hourComboBox.width
                            implicitHeight: Math.min(contentItem.implicitHeight, 220)
                            padding: 1

                            contentItem: ListView {
                                clip: true
                                implicitHeight: contentHeight
                                model: hourComboBox.popup.visible ? hourComboBox.delegateModel : null
                                currentIndex: hourComboBox.highlightedIndex
                                ScrollIndicator.vertical: ScrollIndicator { }
                            }

                            background: Rectangle {
                                border.color: Theme.border
                                color: Theme.surface
                                radius: Theme.radius
                            }
                        }
                    }

                    ComboBox {
                        id: minuteComboBox
                        Layout.fillWidth: true
                        Layout.preferredHeight: Theme.buttonHeight
                        textRole: "label"
                        valueRole: "value"
                        model: temporalMinuteModel
                        currentIndex: Math.max(0, Math.min(temporalMinuteModel.count - 1, root.temporalDraftMinute))
                        onCurrentIndexChanged: {
                            if (currentIndex >= 0 && currentIndex < temporalMinuteModel.count) {
                                root.temporalDraftMinute = Number(temporalMinuteModel.get(currentIndex).value)
                            }
                        }

                        background: Rectangle {
                            implicitHeight: Theme.buttonHeight
                            color: Theme.surface
                            border.color: parent.activeFocus ? root.accentColor : Theme.border
                            border.width: 1
                            radius: Theme.radius
                        }

                        contentItem: Text {
                            leftPadding: 10
                            rightPadding: 10
                            text: minuteComboBox.displayText
                            color: Theme.textPrimary
                            font.pixelSize: 13
                            verticalAlignment: Text.AlignVCenter
                            elide: Text.ElideRight
                        }

                        delegate: ItemDelegate {
                            required property string label
                            required property int index
                            width: minuteComboBox.width
                            height: 30
                            contentItem: Text {
                                text: label
                                color: Theme.textPrimary
                                font.pixelSize: 13
                                elide: Text.ElideRight
                                verticalAlignment: Text.AlignVCenter
                                opacity: 1.0
                            }
                            background: Rectangle {
                                color: highlighted ? Theme.surfaceHighlight : Theme.surface
                            }
                            highlighted: minuteComboBox.highlightedIndex === index
                        }

                        popup: Popup {
                            y: minuteComboBox.height - 1
                            width: minuteComboBox.width
                            implicitHeight: Math.min(contentItem.implicitHeight, 220)
                            padding: 1

                            contentItem: ListView {
                                clip: true
                                implicitHeight: contentHeight
                                model: minuteComboBox.popup.visible ? minuteComboBox.delegateModel : null
                                currentIndex: minuteComboBox.highlightedIndex
                                ScrollIndicator.vertical: ScrollIndicator { }
                            }

                            background: Rectangle {
                                border.color: Theme.border
                                color: Theme.surface
                                radius: Theme.radius
                            }
                        }
                    }
                }
            }

            RowLayout {
                Layout.fillWidth: true
                spacing: Theme.spacingSmall

                AppButton {
                    text: "Now"
                    isOutline: true
                    accentColor: root.accentColor
                    onClicked: root.applyTemporalNow()
                }

                Item { Layout.fillWidth: true }

                AppButton {
                    text: "Cancel"
                    isPrimary: false
                    onClicked: temporalEditorPopup.close()
                }

                AppButton {
                    text: "Submit"
                    isPrimary: true
                    accentColor: root.accentColor
                    onClicked: root.applyTemporalSubmit()
                }
            }
        }
    }

    Popup {
        id: expandedTextPopup
        parent: Overlay.overlay
        modal: true
        focus: true
        closePolicy: Popup.NoAutoClose
        width: {
            if (!parent) return 920
            return Math.min(980, Math.max(520, parent.width - (Theme.spacingXLarge * 2)))
        }
        height: {
            if (!parent) return 620
            return Math.min(700, Math.max(360, parent.height - (Theme.spacingXLarge * 2)))
        }
        x: Math.round((parent.width - width) / 2)
        y: Math.round((parent.height - height) / 2)
        padding: 0

        background: Rectangle {
            color: Theme.surface
            border.color: Theme.border
            border.width: 1
            radius: 10
        }

        contentItem: ColumnLayout {
            anchors.fill: parent
            spacing: 0

            Rectangle {
                Layout.fillWidth: true
                color: Theme.surfaceHighlight
                border.color: Theme.border
                border.width: 1
                implicitHeight: expandedHeader.implicitHeight + (Theme.spacingLarge * 2)

                RowLayout {
                    id: expandedHeader
                    anchors.fill: parent
                    anchors.margins: Theme.spacingLarge
                    spacing: Theme.spacingMedium

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 2

                        RowLayout {
                            Layout.fillWidth: true
                            spacing: Theme.spacingSmall

                            Text {
                                text: expandedFieldName
                                color: Theme.textPrimary
                                font.pixelSize: 16
                                font.bold: true
                                elide: Text.ElideRight
                            }

                            Text {
                                text: expandedFieldType
                                visible: text.length > 0
                                color: Theme.textSecondary
                                font.pixelSize: 11
                            }

                            Item { Layout.fillWidth: true }
                        }

                        Text {
                            Layout.fillWidth: true
                            text: "Expanded text editor"
                            color: Theme.textSecondary
                            font.pixelSize: 12
                        }
                    }

                    AppButton {
                        text: "Close"
                        isPrimary: false
                        enabled: !root.submitting
                        onClicked: expandedTextPopup.close()
                    }
                }
            }

            Rectangle {
                Layout.fillWidth: true
                Layout.fillHeight: true
                color: Theme.surface
                border.color: Theme.border
                border.width: 1

                TextArea {
                    id: expandedTextInput
                    anchors.fill: parent
                    enabled: !root.submitting
                    wrapMode: TextEdit.Wrap
                    selectByMouse: true
                    color: Theme.textPrimary
                    selectionColor: root.accentColor
                    selectedTextColor: "#FFFFFF"
                    leftPadding: Theme.spacingLarge
                    rightPadding: Theme.spacingLarge
                    topPadding: Theme.spacingLarge
                    bottomPadding: Theme.spacingLarge
                    font.pixelSize: 14
                    background: Rectangle {
                        color: "transparent"
                    }
                    onTextChanged: {
                        root.expandedFieldValue = text
                    }
                }
            }

            Rectangle {
                Layout.fillWidth: true
                color: Theme.surface
                border.color: Theme.border
                border.width: 1
                implicitHeight: expandedFooter.implicitHeight + (Theme.spacingLarge * 2)

                RowLayout {
                    id: expandedFooter
                    anchors.fill: parent
                    anchors.margins: Theme.spacingLarge
                    spacing: Theme.spacingMedium

                    Item { Layout.fillWidth: true }

                    AppButton {
                        text: "Cancel"
                        isPrimary: false
                        enabled: !root.submitting
                        onClicked: expandedTextPopup.close()
                    }

                    AppButton {
                        text: "Apply"
                        isPrimary: true
                        accentColor: root.accentColor
                        enabled: !root.submitting
                        onClicked: root.applyExpandedTextEditor()
                    }
                }
            }
        }
    }

    Popup {
        id: closeConfirmPopup
        parent: Overlay.overlay
        modal: true
        focus: true
        closePolicy: Popup.NoAutoClose
        width: 360
        x: Math.round((parent.width - width) / 2)
        y: Math.round((parent.height - height) / 2)
        padding: Theme.spacingLarge
        implicitHeight: confirmContent.implicitHeight + topPadding + bottomPadding

        background: Rectangle {
            color: Theme.surface
            border.color: Theme.border
            border.width: 1
            radius: 8
        }

        contentItem: ColumnLayout {
            id: confirmContent
            width: closeConfirmPopup.availableWidth
            spacing: Theme.spacingMedium

            Text {
                Layout.fillWidth: true
                text: "Close and discard changes?"
                color: Theme.textPrimary
                font.pixelSize: 15
                font.bold: true
                wrapMode: Text.WordWrap
            }

            Text {
                Layout.fillWidth: true
                text: "Any values typed in this form will be lost."
                color: Theme.textSecondary
                font.pixelSize: 12
                wrapMode: Text.WordWrap
            }

            RowLayout {
                Layout.fillWidth: true
                spacing: Theme.spacingMedium

                Item { Layout.fillWidth: true }

                AppButton {
                    text: "Keep Editing"
                    isPrimary: false
                    onClicked: closeConfirmPopup.close()
                }

                AppButton {
                    text: "Discard"
                    isPrimary: true
                    accentColor: root.accentColor
                    onClicked: root.confirmAndClose()
                }
            }
        }
    }
}
