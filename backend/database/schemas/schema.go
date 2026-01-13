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

type ForeignKeyAction string

const (
	FKNoAction   ForeignKeyAction = "NO ACTION"
	FKRestrict   ForeignKeyAction = "RESTRICT"
	FKSetNull    ForeignKeyAction = "SET NULL"
	FKSetDefault ForeignKeyAction = "SET DEFAULT"
	FKCascade    ForeignKeyAction = "CASCADE"
)

type ForeignKeyMatch struct {
	TargetSchema string
	ColumnName   string
	OnDelete     ForeignKeyAction // optional
	OnUpdate     ForeignKeyAction // optional
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
		return "timestamptz"
	case ColumnUUID:
		return "uuid"
	default:
		// fallback to something safe so schema generation never explodes
		return "varchar(255)"
	}
}

func columnToString(col Column, pkCount int) string {
	var parts []string

	// name + type
	parts = append(parts, col.Name)
	parts = append(parts, columnTypeToString(col.Type))

	// constraints
	if col.PrimaryKey && pkCount <= 1 {
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
		ref := "REFERENCES " + fk.TargetSchema + "(" + fk.ColumnName + ")"

		if fk.OnDelete != "" {
			ref += " ON DELETE " + string(fk.OnDelete)
		}
		if fk.OnUpdate != "" {
			ref += " ON UPDATE " + string(fk.OnUpdate)
		}

		parts = append(parts, ref)
	}

	return strings.Join(parts, " ")
}

func schemaToCreationString(schema Schema) string {
	cols := make([]string, 0, len(schema.Columns))

	// Collect PK columns
	var pkCols []string
	for _, col := range schema.Columns {
		if col.PrimaryKey {
			pkCols = append(pkCols, col.Name)
		}
	}

	for _, col := range schema.Columns {
		cols = append(cols, columnToString(col, len(pkCols)))
	}

	// Add table-level primary key if needed
	if len(pkCols) > 1 {
		cols = append(cols, "PRIMARY KEY ("+strings.Join(pkCols, ", ")+")")
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
