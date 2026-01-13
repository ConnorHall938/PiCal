package schemas

import (
	"context"
	"database/sql"
	"fmt"
)

type Event struct {
	EventID    string  `json:"eventId"`
	PersonName string  `json:"personName"`
	Title      string  `json:"title"`
	Notes      *string `json:"notes,omitempty"`
	Timezone   string  `json:"timezone"`
	AllDay     bool    `json:"allDay"`
	Rrule      *string `json:"rrule,omitempty"`
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

func CreateEvent(ctx context.Context, db *sql.DB, in Event) (Event, error) {
	if db == nil {
		return Event{}, fmt.Errorf("db is nil")
	}

	// Minimal validation (optional but recommended)
	if in.PersonName == "" {
		return Event{}, fmt.Errorf("personName is required")
	}
	if in.Title == "" {
		return Event{}, fmt.Errorf("title is required")
	}
	if in.Timezone == "" {
		return Event{}, fmt.Errorf("timezone is required")
	}

	row := db.QueryRowContext(ctx, `
		INSERT INTO events (personName, title, notes, timezone, allDay, rrule)
		VALUES ($1, $2, $3, $4, $5, $6)
		RETURNING eventID, personName, title, notes, timezone, allDay, rrule;
	`, in.PersonName, in.Title, in.Notes, in.Timezone, in.AllDay, in.Rrule)

	var out Event
	if err := row.Scan(
		&out.EventID,
		&out.PersonName,
		&out.Title,
		&out.Notes,
		&out.Timezone,
		&out.AllDay,
		&out.Rrule,
	); err != nil {
		return Event{}, fmt.Errorf("insert event: %w", err)
	}

	return out, nil
}

// ListEvents returns all events (add paging later).
func ListEvents(ctx context.Context, db *sql.DB) ([]Event, error) {
	if db == nil {
		return nil, fmt.Errorf("db is nil")
	}

	rows, err := db.QueryContext(ctx, `
		SELECT eventID, personName, title, notes, timezone, allDay, rrule
		FROM events
		ORDER BY personName, title, eventID;
	`)
	if err != nil {
		return nil, fmt.Errorf("list events query: %w", err)
	}
	defer rows.Close()

	out := make([]Event, 0)
	for rows.Next() {
		var e Event
		if err := rows.Scan(&e.EventID, &e.PersonName, &e.Title, &e.Notes, &e.Timezone, &e.AllDay, &e.Rrule); err != nil {
			return nil, fmt.Errorf("list events scan: %w", err)
		}
		out = append(out, e)
	}
	if err := rows.Err(); err != nil {
		return nil, fmt.Errorf("list events rows: %w", err)
	}

	return out, nil
}
