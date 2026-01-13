package schemas

import "time"

type OccurrenceType int

const (
	OccurrenceNormal OccurrenceType = iota
	OccurrenceMoved
	OccurrenceCancelled
)

type Occurrence struct {
	EventID      string         `json:"eventId"`
	StartTime    time.Time      `json:"startTime"`
	EndTime      *time.Time     `json:"endTime,omitempty"`
	Kind         OccurrenceType `json:"moved"`
	NewStartTime *time.Time     `json:"newStartTime,omitempty"`
	NewEndTime   *time.Time     `json:"newEndTime,omitempty"`
}

func CreateOccurrenceSchema() Schema {
	cols := make([]Column, 0)
	cols = append(cols,
		Column{Name: "eventID",
			Type:       ColumnUUID,
			PrimaryKey: true,
			ForeignKey: []ForeignKeyMatch{{TargetSchema: "Events", ColumnName: "eventID", OnDelete: FKCascade}}},
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
