package schemas

import (
	"context"
	"database/sql"
	"fmt"
	"log"
	"time"
)

type OccurrenceKind int

const (
	OccurrenceNormal OccurrenceKind = iota
	OccurrenceMoved
	OccurrenceCancelled
)

type Occurrence struct {
	OccurrenceID string         `json:"occurrenceId"`
	EventID      string         `json:"eventId"`
	StartTime    time.Time      `json:"startTime"`
	EndTime      *time.Time     `json:"endTime,omitempty"`
	Kind         OccurrenceKind `json:"moved"`
	NewStartTime *time.Time     `json:"newStartTime,omitempty"`
	NewEndTime   *time.Time     `json:"newEndTime,omitempty"`
}

func CreateOccurrenceSchema() Schema {
	cols := make([]Column, 0)
	cols = append(cols,
		Column{Name: "occurrenceID",
			Type:           ColumnUUID,
			PrimaryKey:     true,
			DefaultSQLExpr: DefaultUUID()},
		Column{Name: "eventID",
			Type:       ColumnUUID,
			ForeignKey: []ForeignKeyMatch{{TargetSchema: "Events", ColumnName: "eventID", OnDelete: FKCascade}}},
		Column{Name: "startTime",
			Type: ColumnTimestamp},
		Column{Name: "endTime",
			Type:     ColumnTimestamp,
			Nullable: true},
		Column{Name: "occurrenceKind",
			Type:           ColumnInt,
			DefaultSQLExpr: SQLDefault(fmt.Sprintf("%d", OccurrenceNormal))},
		Column{Name: "newStartTime",
			Type:     ColumnTimestamp,
			Nullable: true},
		Column{Name: "newEndTime",
			Type:     ColumnTimestamp,
			Nullable: true},
	)

	schema := Schema{Name: "occurrences", Columns: cols}
	return schema
}

func CreateOccurrence(ctx context.Context, db *sql.DB, in Occurrence) (Occurrence, error) {
	if db == nil {
		return Occurrence{}, fmt.Errorf("db is nil")
	}

	// Minimal validation (optional but recommended)
	if in.EventID == "" {
		return Occurrence{}, fmt.Errorf("EventID is required")
	}

	if in.Kind != OccurrenceNormal {
		return Occurrence{}, fmt.Errorf("Cannot create an occurrence that is already moved")
	}

	row := db.QueryRowContext(ctx, `
		INSERT INTO occurrences (eventID, startTime, endTime, occurrenceKind, newStartTime, newEndTime)
		VALUES ($1, $2, $3, $4, $5, $6)
		RETURNING occurrenceID, eventID, startTime, endTime, occurrenceKind, newStartTime, newEndTime;
	`, in.EventID, in.StartTime, in.EndTime, in.Kind, in.NewStartTime, in.NewEndTime)

	var out Occurrence
	if err := row.Scan(
		&out.OccurrenceID,
		&out.EventID,
		&out.StartTime,
		&out.EndTime,
		&out.Kind,
		&out.NewStartTime,
		&out.NewStartTime,
	); err != nil {
		return Occurrence{}, fmt.Errorf("insert occurrence: %w", err)
	}

	return out, nil
}

func DeleteOccurrence(
	ctx context.Context,
	db *sql.DB,
	id string,
) error {
	if db == nil {
		return fmt.Errorf("db is nil")
	}

	result, err := db.ExecContext(ctx, `
		DELETE FROM occurrences WHERE occurrenceID = $1`, id)
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

func ListOccurrences(
	ctx context.Context,
	db *sql.DB,
	limit, offset int,
) ([]Occurrence, int, error) {

	if db == nil {
		return nil, 0, fmt.Errorf("db is nil")
	}

	rows, err := db.QueryContext(ctx, `
		SELECT
			occurrenceID,
			eventID, 
			startTime, 
			endTime, 
			occurrenceKind, 
			newStartTime, 
			newEndTime,
			COUNT(*) OVER() AS total_count
		FROM occurrences
		ORDER BY startTime, eventID
		LIMIT $1 OFFSET $2;
	`, limit, offset)
	if err != nil {
		return nil, 0, fmt.Errorf("list occurrences query: %w", err)
	}
	defer rows.Close()

	occurrences := make([]Occurrence, 0, limit)
	total := 0

	for rows.Next() {
		var o Occurrence
		if err := rows.Scan(
			&o.OccurrenceID,
			&o.EventID,
			&o.StartTime,
			&o.EndTime,
			&o.Kind,
			&o.NewStartTime,
			&o.NewEndTime,
			&total, // same value for every row
		); err != nil {
			return nil, 0, fmt.Errorf("list occurrences scan: %w", err)
		}
		occurrences = append(occurrences, o)
	}

	if err := rows.Err(); err != nil {
		return nil, 0, fmt.Errorf("list occurrences rows: %w", err)
	}

	return occurrences, total, nil
}

func GetOccurrence(
	ctx context.Context,
	db *sql.DB,
	id string,
) (*Occurrence, error) {
	if db == nil {
		return nil, fmt.Errorf("db is nil")
	}

	row := db.QueryRowContext(ctx, `
		SELECT occurrenceID, eventID, startTime, endTime, occurrenceKind, newStartTime, newEndTime
		FROM occurrences
		WHERE occurrenceID = $1
	`, id)

	if row.Err() != nil {
		return nil, fmt.Errorf("Failed to query occurrences: %w", row.Err())
	}

	var o Occurrence
	if err := row.Scan(
		&o.OccurrenceID,
		&o.EventID,
		&o.StartTime,
		&o.EndTime,
		&o.Kind,
		&o.NewStartTime,
		&o.NewEndTime,
	); err != nil {
		return nil, fmt.Errorf("list occurrences scan: %w", err)
	}

	return &o, nil
}
