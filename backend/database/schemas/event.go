package schemas

import (
	"context"
	"database/sql"
	"fmt"
	"log"
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

func DeleteEvent(
	ctx context.Context,
	db *sql.DB,
	id string,
) error {
	if db == nil {
		return fmt.Errorf("db is nil")
	}

	result, err := db.ExecContext(ctx, `
		DELETE FROM events WHERE eventID = $1`, id)
	if err != nil {
		return fmt.Errorf("Failed to execute event delete statement: %w", err)
	}

	rowsAffected, err := result.RowsAffected()
	if err != nil {
		log.Printf("could not get rows affected: %v", err)
	}
	if rowsAffected == 0 {
		return sql.ErrNoRows
	}

	return nil
}

func ListEvents(
	ctx context.Context,
	db *sql.DB,
	limit, offset int,
) ([]Event, int, error) {

	if db == nil {
		return nil, 0, fmt.Errorf("db is nil")
	}

	rows, err := db.QueryContext(ctx, `
		SELECT
			eventID,
			personName,
			title,
			notes,
			timezone,
			allDay,
			rrule,
			COUNT(*) OVER() AS total_count
		FROM events
		ORDER BY personName, title, eventID
		LIMIT $1 OFFSET $2;
	`, limit, offset)
	if err != nil {
		return nil, 0, fmt.Errorf("list events query: %w", err)
	}
	defer rows.Close()

	events := make([]Event, 0, limit)
	total := 0

	for rows.Next() {
		var e Event
		if err := rows.Scan(
			&e.EventID,
			&e.PersonName,
			&e.Title,
			&e.Notes,
			&e.Timezone,
			&e.AllDay,
			&e.Rrule,
			&total, // same value for every row
		); err != nil {
			return nil, 0, fmt.Errorf("list events scan: %w", err)
		}
		events = append(events, e)
	}

	if err := rows.Err(); err != nil {
		return nil, 0, fmt.Errorf("list events rows: %w", err)
	}

	return events, total, nil
}

func GetEvent(
	ctx context.Context,
	db *sql.DB,
	id string,
) (*Event, error) {
	if db == nil {
		return nil, fmt.Errorf("db is nil")
	}

	row := db.QueryRowContext(ctx, `
		SELECT eventID, personName, title, notes, timezone, allDay, rrule
		FROM events
		WHERE eventID = $1
	`, id)

	if row.Err() != nil {
		return nil, fmt.Errorf("Failed to query events: %w", row.Err())
	}

	var e Event
	if err := row.Scan(
		&e.EventID,
		&e.PersonName,
		&e.Title,
		&e.Notes,
		&e.Timezone,
		&e.AllDay,
		&e.Rrule,
	); err != nil {
		return nil, fmt.Errorf("list events scan: %w", err)
	}

	return &e, nil
}
