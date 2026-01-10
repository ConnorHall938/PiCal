package schemas

import "time"

type Occurrence struct {
	EventID      string
	StartTime    time.Time
	EndTime      *time.Time
	Moved        bool
	NewStartTime *time.Time
	NewEndTime   *time.Time
}

func CreateOccurrenceSchema() Schema {
	cols := make([]Column, 0)
	cols = append(cols,
		Column{Name: "eventID",
			Type:       ColumnUUID,
			PrimaryKey: true,
			ForeignKey: []ForeignKeyMatch{{TargetSchema: "Events", ColumnName: "eventID"}}},
		Column{Name: "startTime",
			Type: ColumnTimestamp},
		Column{Name: "endTime",
			Type:     ColumnTimestamp,
			Nullable: true},
		Column{Name: "moved",
			Type:           ColumnBool,
			DefaultSQLExpr: SQLDefault("FALSE")},
		Column{Name: "oldStartTime",
			Type:     ColumnTimestamp,
			Nullable: true},
		Column{Name: "oldEndTime",
			Type:     ColumnTimestamp,
			Nullable: true},
	)

	schema := Schema{Name: "occurrences", Columns: cols}
	return schema
}
