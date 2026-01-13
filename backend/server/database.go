package server

import (
	"context"
	"pical/database/schemas"
	"time"
)

func (s *Server) initDatabase(ctx context.Context) error {

	ctx, cancel := context.WithTimeout(ctx, 60*time.Second)
	defer cancel()

	targetSchema := schemas.CreateEventSchema()
	if err := schemas.CreateSchema(ctx, s.DB, targetSchema); err != nil {
		return err
	}

	targetSchema = schemas.CreateOccurrenceSchema()
	if err := schemas.CreateSchema(ctx, s.DB, targetSchema); err != nil {
		return err
	}

	targetSchema = schemas.CreateExceptionSchema()
	if err := schemas.CreateSchema(ctx, s.DB, targetSchema); err != nil {
		return err
	}

	return nil
}
