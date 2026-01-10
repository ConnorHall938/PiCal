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
	EventID      string
	RecurrenceID string
	Kind         ExceptionType
	NewStart     time.Time
	NewEnd       time.Time
}

func CreateExceptionSchema() Schema {
	cols := make([]Column, 0)
	cols = append(cols,
		Column{Name: "eventID",
			Type:       ColumnUUID,
			PrimaryKey: true,
			ForeignKey: []ForeignKeyMatch{{TargetSchema: "events", ColumnName: "eventID"}}},
		Column{Name: "recurrenceID",
			Type:       ColumnTimestamp,
			PrimaryKey: true},
		Column{Name: "kind",
			Type: ColumnInt},
		Column{Name: "newStart",
			Type: ColumnTimestamp},
		Column{Name: "newEnd",
			Type: ColumnTimestamp},
	)

	schema := Schema{Name: "exceptions", Columns: cols}
	return schema
}
