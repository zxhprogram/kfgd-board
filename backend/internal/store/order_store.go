package store

import (
	"context"
	"database/sql"
	"encoding/json"
	"errors"
	"os"
	"path/filepath"

	"backend/internal/model"

	_ "modernc.org/sqlite"
)

const defaultDBPath = "data/backend.db"

type OrderStore struct {
	db *sql.DB
}

type SavedBusinessOrder struct {
	ProId         string                   `json:"proId"`
	ProTitle      string                   `json:"proTitle"`
	CustomerName  string                   `json:"customerName"`
	CustomerPhone string                   `json:"customerPhone"`
	ProState      int                      `json:"proState"`
	CreateTime    string                   `json:"createTime"`
	UpdateTime    string                   `json:"updateTime"`
	Raw           model.BusinessOrderValue `json:"raw"`
	SavedAt       string                   `json:"savedAt"`
}

func OpenOrderStore(dbPath string) (*OrderStore, error) {
	if dbPath == "" {
		dbPath = os.Getenv("SQLITE_PATH")
	}
	if dbPath == "" {
		dbPath = defaultDBPath
	}
	if dir := filepath.Dir(dbPath); dir != "." {
		if err := os.MkdirAll(dir, 0755); err != nil {
			return nil, err
		}
	}

	db, err := sql.Open("sqlite", dbPath)
	if err != nil {
		return nil, err
	}
	store := &OrderStore{db: db}
	if err := store.init(context.Background()); err != nil {
		db.Close()
		return nil, err
	}
	return store, nil
}

func (s *OrderStore) Close() error {
	return s.db.Close()
}

func (s *OrderStore) init(ctx context.Context) error {
	_, err := s.db.ExecContext(ctx, `
CREATE TABLE IF NOT EXISTS business_orders (
	pro_id TEXT PRIMARY KEY,
	pro_title TEXT,
	customer_name TEXT,
	customer_phone TEXT,
	pro_state INTEGER,
	create_time TEXT,
	update_time TEXT,
	raw_json TEXT NOT NULL,
	saved_at DATETIME DEFAULT CURRENT_TIMESTAMP
);
CREATE INDEX IF NOT EXISTS idx_business_orders_saved_at ON business_orders(saved_at);
`)
	return err
}

func (s *OrderStore) UpsertOrders(ctx context.Context, values []model.BusinessOrderValue) error {
	if len(values) == 0 {
		return nil
	}
	tx, err := s.db.BeginTx(ctx, nil)
	if err != nil {
		return err
	}
	defer tx.Rollback()

	stmt, err := tx.PrepareContext(ctx, `
INSERT INTO business_orders (
	pro_id, pro_title, customer_name, customer_phone, pro_state, create_time, update_time, raw_json, saved_at
) VALUES (?, ?, ?, ?, ?, ?, ?, ?, CURRENT_TIMESTAMP)
ON CONFLICT(pro_id) DO UPDATE SET
	pro_title = excluded.pro_title,
	customer_name = excluded.customer_name,
	customer_phone = excluded.customer_phone,
	pro_state = excluded.pro_state,
	create_time = excluded.create_time,
	update_time = excluded.update_time,
	raw_json = excluded.raw_json,
	saved_at = CURRENT_TIMESTAMP
`)
	if err != nil {
		return err
	}
	defer stmt.Close()

	for _, value := range values {
		if value.ProId == "" {
			return errors.New("proId is required")
		}
		raw, err := json.Marshal(value)
		if err != nil {
			return err
		}
		if _, err := stmt.ExecContext(ctx, value.ProId, value.ProTitle, value.CustomerName, value.CustomerPhone, value.ProState, value.CreateTime, value.UpdateTime, string(raw)); err != nil {
			return err
		}
	}

	return tx.Commit()
}

func (s *OrderStore) ListOrders(ctx context.Context, pageNo int, pageSize int) ([]SavedBusinessOrder, int, error) {
	if pageNo < 1 {
		pageNo = 1
	}
	if pageSize < 1 {
		pageSize = 10
	}
	offset := (pageNo - 1) * pageSize

	var total int
	if err := s.db.QueryRowContext(ctx, `SELECT COUNT(*) FROM business_orders`).Scan(&total); err != nil {
		return nil, 0, err
	}

	rows, err := s.db.QueryContext(ctx, `
SELECT pro_id, pro_title, customer_name, customer_phone, pro_state, create_time, update_time, raw_json, saved_at
FROM business_orders
ORDER BY saved_at DESC, pro_id DESC
LIMIT ? OFFSET ?
`, pageSize, offset)
	if err != nil {
		return nil, 0, err
	}
	defer rows.Close()

	items := make([]SavedBusinessOrder, 0)
	for rows.Next() {
		var item SavedBusinessOrder
		var raw string
		if err := rows.Scan(&item.ProId, &item.ProTitle, &item.CustomerName, &item.CustomerPhone, &item.ProState, &item.CreateTime, &item.UpdateTime, &raw, &item.SavedAt); err != nil {
			return nil, 0, err
		}
		if err := json.Unmarshal([]byte(raw), &item.Raw); err != nil {
			return nil, 0, err
		}
		items = append(items, item)
	}
	if err := rows.Err(); err != nil {
		return nil, 0, err
	}

	return items, total, nil
}
