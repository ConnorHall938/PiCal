package schemas

import (
	"time"
)

type ExceptionType int

const (
	ExceptionCancel ExceptionType = iota
	ExceptionMove
)

type Exception struct {
	EventID      string        `json:"eventId"`
	RecurrenceID string        `json:"recurrenceId"`
	Kind         ExceptionType `json:"kind"`
	NewStart     *time.Time    `json:"newStart,omitempty"`
	NewEnd       *time.Time    `json:"newEnd,omitempty"`
}

func CreateExceptionSchema() Schema {
	cols := make([]Column, 0)
	cols = append(cols,
		Column{Name: "eventID",
			Type:       ColumnUUID,
			PrimaryKey: true,
			ForeignKey: []ForeignKeyMatch{{TargetSchema: "events", ColumnName: "eventID", OnDelete: FKCascade}}},
		Column{Name: "recurrenceID",
			Type:       ColumnTimestamp,
			PrimaryKey: true},
		Column{Name: "kind",
			Type: ColumnInt},
		Column{Name: "newStart",
			Type:     ColumnTimestamp,
			Nullable: true},
		Column{Name: "newEnd",
			Type:     ColumnTimestamp,
			Nullable: true},
	)

	schema := Schema{Name: "exceptions", Columns: cols}
	return schema
}
