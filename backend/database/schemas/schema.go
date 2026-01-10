package schemas

import (
	"context"
	"database/sql"
	"fmt"
	"strings"
)

// Helper that lets us wrap SQL strings to be used as the default expression.
// This is necessary as we use a pointer and its weird
func SQLDefault(expr string) *string { return &expr }

func DefaultNow() *string {
	return SQLDefault("CURRENT_TIMESTAMP")
}

func DefaultTrue() *string {
	return SQLDefault("TRUE")
}

func DefaultFalse() *string {
	return SQLDefault("FALSE")
}

func DefaultTimezone() *string {
	return SQLDefault("'UTC'")
}

func DefaultUUID() *string {
	return SQLDefault("gen_random_uuid()")
}

type ColumnType int

const (
	ColumnString ColumnType = iota
	ColumnInt
	ColumnBool
	ColumnTimestamp
	ColumnUUID
)

type ForeignKeyMatch struct {
	TargetSchema string
	ColumnName   string
}

type Column struct {
	Name           string
	Type           ColumnType
	PrimaryKey     bool // Default no
	ForeignKey     []ForeignKeyMatch
	Nullable       bool    // Default no
	DefaultSQLExpr *string // nil = no default; otherwise literal SQL like "'abc'" or "CURRENT_TIMESTAMP"
}

type Schema struct {
	Name    string
	Columns []Column
}

func columnTypeToString(colType ColumnType) string {
	switch colType {
	case ColumnString:
		return "varchar(255)"
	case ColumnInt:
		return "integer"
	case ColumnBool:
		return "boolean"
	case ColumnTimestamp:
		return "timestamptzc"
	case ColumnUUID:
		return "uuid"
	default:
		// fallback to something safe so schema generation never explodes
		return "varchar(255)"
	}
}

func columnToString(col Column) string {
	var parts []string

	// name + type
	parts = append(parts, col.Name)
	parts = append(parts, columnTypeToString(col.Type))

	// constraints
	if col.PrimaryKey {
		parts = append(parts, "PRIMARY KEY")
	}
	if !col.Nullable {
		parts = append(parts, "NOT NULL")
	}
	if col.DefaultSQLExpr != nil {
		parts = append(parts, "DEFAULT "+*col.DefaultSQLExpr)
	}

	// foreign keys (if you allow multiple, emit multiple REFERENCES clauses)
	for _, fk := range col.ForeignKey {
		parts = append(parts, "REFERENCES "+fk.TargetSchema+"("+fk.ColumnName+")")
	}

	return strings.Join(parts, " ")
}

func schemaToCreationString(schema Schema) string {
	var cols []string
	cols = make([]string, 0, len(schema.Columns))

	for _, col := range schema.Columns {
		cols = append(cols, columnToString(col))
	}

	return "CREATE TABLE IF NOT EXISTS " + schema.Name + " (" + strings.Join(cols, ", ") + ");"
}

func CreateSchema(ctx context.Context, db *sql.DB, schema Schema) error {
	if db == nil {
		return fmt.Errorf("db is nil")
	}
	if schema.Name == "" {
		return fmt.Errorf("schema name is empty")
	}

	sqlStr := schemaToCreationString(schema)

	if _, err := db.ExecContext(ctx, sqlStr); err != nil {
		return fmt.Errorf("create schema %q failed: %w\nSQL: %s", schema.Name, err, sqlStr)
	}

	return nil
}
