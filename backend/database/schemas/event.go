package schemas

type Event struct {
	EventID    string
	PersonName string
	Title      string
	Notes      *string
	Timezone   string
	AllDay     bool
	Rrule      *string
}

func CreateEventSchema() Schema {
	cols := make([]Column, 0)
	cols = append(cols,
		Column{Name: "eventID",
			Type:           ColumnUUID,
			PrimaryKey:     true,
			DefaultSQLExpr: DefaultUUID()},
		Column{Name: "personName",
			Type: ColumnString},
		Column{Name: "title",
			Type: ColumnString},
		Column{Name: "notes",
			Type:     ColumnString,
			Nullable: true},
		Column{Name: "timezone",
			Type:           ColumnString,
			DefaultSQLExpr: DefaultTimezone()},
		Column{Name: "allDay",
			Type:           ColumnBool,
			DefaultSQLExpr: DefaultFalse()},
		Column{Name: "rrule",
			Type:     ColumnString,
			Nullable: true},
	)

	schema := Schema{Name: "events", Columns: cols}
	return schema
}
