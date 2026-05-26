package store

import (
	"context"
	"database/sql"
	"encoding/json"
	"errors"
	"fmt"
	"os"
	"path/filepath"
	"strings"
	"time"

	"backend/internal/model"

	_ "modernc.org/sqlite"
)

const defaultDBPath = "data/backend.db"

type OrderStore struct {
	db *sql.DB
}

type SavedBusinessOrder struct {
	ProId           string                   `json:"proId"`
	ExternalNo      string                   `json:"externalNo"`
	ProTitle        string                   `json:"proTitle"`
	CustomerName    string                   `json:"customerName"`
	CustomerPhone   string                   `json:"customerPhone"`
	ProState        int                      `json:"proState"`
	CreateTime      string                   `json:"createTime"`
	UpdateTime      string                   `json:"updateTime"`
	StartTime       string                   `json:"startTime"`
	ResolveTime     string                   `json:"resolveTime"`
	Raw             model.BusinessOrderValue `json:"raw"`
	SavedAt         string                   `json:"savedAt"`
	ProcessDuration string                   `json:"processDuration"`
}

type SavedOperLog struct {
	Id        int64           `json:"id"`
	ProId     string          `json:"proId"`
	OperId    string          `json:"operId"`
	Raw       model.OperLogVo `json:"raw"`
	CreatedAt string          `json:"createdAt"`
}

type SavedZenTaoProblem struct {
	Id        int64               `json:"id"`
	ProId     string              `json:"proId"`
	Raw       model.ZenTaoProblem `json:"raw"`
	CreatedAt string              `json:"createdAt"`
}

type SavedChildItem struct {
	Id          int64  `json:"id"`
	ProId       string `json:"proId"`
	ParentProId string `json:"parentProId"`
}

type DailyCount struct {
	Date  string `json:"date"`
	Count int    `json:"count"`
}

type DurationBucket struct {
	Label string `json:"label"`
	Count int    `json:"count"`
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
	external_no TEXT DEFAULT '',
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

CREATE TABLE IF NOT EXISTS business_order_oper_logs (
	id INTEGER PRIMARY KEY AUTOINCREMENT,
	pro_id TEXT NOT NULL,
	oper_id TEXT NOT NULL UNIQUE,
	raw_json TEXT NOT NULL,
	created_at DATETIME DEFAULT CURRENT_TIMESTAMP
);
CREATE INDEX IF NOT EXISTS idx_oper_logs_pro_id ON business_order_oper_logs(pro_id);

CREATE TABLE IF NOT EXISTS business_order_zen_tao_problems (
	id INTEGER PRIMARY KEY AUTOINCREMENT,
	pro_id TEXT NOT NULL UNIQUE,
	raw_json TEXT NOT NULL,
	created_at DATETIME DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS business_order_children (
	id INTEGER PRIMARY KEY AUTOINCREMENT,
	pro_id TEXT NOT NULL,
	parent_pro_id TEXT NOT NULL,
	remote_id INTEGER NOT NULL,
	UNIQUE(pro_id, parent_pro_id)
);
CREATE INDEX IF NOT EXISTS idx_children_pro_id ON business_order_children(pro_id);
CREATE INDEX IF NOT EXISTS idx_children_parent_pro_id ON business_order_children(parent_pro_id);
`)
	if err != nil {
		return err
	}
	if err := s.ensureBusinessOrdersColumns(ctx); err != nil {
		return err
	}
	return s.backfillProcessTimes(ctx)
}

func (s *OrderStore) ensureBusinessOrdersColumns(ctx context.Context) error {
	rows, err := s.db.QueryContext(ctx, `PRAGMA table_info(business_orders)`)
	if err != nil {
		return err
	}
	defer rows.Close()

	hasExternalNo := false
	hasStartTime := false
	hasResolveTime := false
	for rows.Next() {
		var cid int
		var name string
		var columnType string
		var notNull int
		var defaultValue sql.NullString
		var pk int
		if err := rows.Scan(&cid, &name, &columnType, &notNull, &defaultValue, &pk); err != nil {
			return err
		}
		switch name {
		case "external_no":
			hasExternalNo = true
		case "start_time":
			hasStartTime = true
		case "resolve_time":
			hasResolveTime = true
		}
	}
	if err := rows.Err(); err != nil {
		return err
	}

	if !hasExternalNo {
		if _, err := s.db.ExecContext(ctx, `ALTER TABLE business_orders ADD COLUMN external_no TEXT DEFAULT ''`); err != nil {
			return err
		}
	}
	if !hasStartTime {
		if _, err := s.db.ExecContext(ctx, `ALTER TABLE business_orders ADD COLUMN start_time TEXT DEFAULT ''`); err != nil {
			return err
		}
	}
	if !hasResolveTime {
		if _, err := s.db.ExecContext(ctx, `ALTER TABLE business_orders ADD COLUMN resolve_time TEXT DEFAULT ''`); err != nil {
			return err
		}
	}
	return nil
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
	pro_id, external_no, pro_title, customer_name, customer_phone, pro_state, create_time, update_time, start_time, resolve_time, raw_json, saved_at
) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, CURRENT_TIMESTAMP)
ON CONFLICT(pro_id) DO UPDATE SET
	external_no = external_no,
	pro_title = excluded.pro_title,
	customer_name = excluded.customer_name,
	customer_phone = excluded.customer_phone,
	pro_state = excluded.pro_state,
	create_time = excluded.create_time,
	update_time = excluded.update_time,
	start_time = excluded.start_time,
	resolve_time = excluded.resolve_time,
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
		startTime, resolveTime, _ := s.computeProcessTimes(ctx, value.ProId)
		if _, err := stmt.ExecContext(ctx, value.ProId, value.ExternalNo, value.ProTitle, value.CustomerName, value.CustomerPhone, value.ProState, value.CreateTime, value.UpdateTime, startTime, resolveTime, string(raw)); err != nil {
			return err
		}
	}

	return tx.Commit()
}

func (s *OrderStore) ListOrders(ctx context.Context, pageNo int, pageSize int, proIdFilter string, proState *int, startTimeFrom string, startTimeTo string, resolveTimeFrom string, resolveTimeTo string) ([]SavedBusinessOrder, int, error) {
	if pageNo < 1 {
		pageNo = 1
	}
	if pageSize < 1 {
		pageSize = 10
	}
	offset := (pageNo - 1) * pageSize

	var conditions []string
	var args []any

	if proIdFilter != "" {
		conditions = append(conditions, "pro_id LIKE ?")
		args = append(args, "%"+proIdFilter+"%")
	}
	if proState != nil {
		conditions = append(conditions, "pro_state = ?")
		args = append(args, *proState)
	}
	if startTimeFrom != "" {
		conditions = append(conditions, "start_time >= ?")
		args = append(args, startTimeFrom)
	}
	if startTimeTo != "" {
		conditions = append(conditions, "start_time <= ?")
		args = append(args, startTimeTo)
	}
	if resolveTimeFrom != "" {
		conditions = append(conditions, "resolve_time >= ?")
		args = append(args, resolveTimeFrom)
	}
	if resolveTimeTo != "" {
		conditions = append(conditions, "resolve_time <= ?")
		args = append(args, resolveTimeTo)
	}

	whereClause := ""
	if len(conditions) > 0 {
		whereClause = "WHERE " + strings.Join(conditions, " AND ")
	}

	var total int
	countSQL := "SELECT COUNT(*) FROM business_orders " + whereClause
	if err := s.db.QueryRowContext(ctx, countSQL, args...).Scan(&total); err != nil {
		return nil, 0, err
	}

	querySQL := `SELECT pro_id, external_no, pro_title, customer_name, customer_phone, pro_state, create_time, update_time, start_time, resolve_time, raw_json, saved_at
FROM business_orders ` + whereClause + ` ORDER BY saved_at DESC, pro_id DESC LIMIT ? OFFSET ?`

	queryArgs := append(args, pageSize, offset)
	rows, err := s.db.QueryContext(ctx, querySQL, queryArgs...)
	if err != nil {
		return nil, 0, err
	}
	defer rows.Close()

	items := make([]SavedBusinessOrder, 0)
	for rows.Next() {
		var item SavedBusinessOrder
		var raw string
		if err := rows.Scan(&item.ProId, &item.ExternalNo, &item.ProTitle, &item.CustomerName, &item.CustomerPhone, &item.ProState, &item.CreateTime, &item.UpdateTime, &item.StartTime, &item.ResolveTime, &raw, &item.SavedAt); err != nil {
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

	for i := range items {
		if items[i].StartTime != "" {
			items[i].CreateTime = items[i].StartTime
		}
		items[i].UpdateTime = items[i].ResolveTime
		if items[i].StartTime != "" || items[i].ResolveTime != "" {
			items[i].ProcessDuration = s.computeDuration(items[i].StartTime, items[i].ResolveTime)
		} else {
			startTime, resolveTime, duration := s.computeProcessTimes(ctx, items[i].ProId)
			if startTime != "" {
				items[i].CreateTime = startTime
			}
			items[i].UpdateTime = resolveTime
			items[i].ProcessDuration = duration
		}
	}

	return items, total, nil
}

func (s *OrderStore) computeDuration(startTime, resolveTime string) string {
	if startTime == "" {
		return ""
	}
	st, err := time.Parse("2006-01-02 15:04:05", startTime)
	if err != nil {
		return ""
	}
	var et time.Time
	if resolveTime != "" {
		et, err = time.Parse("2006-01-02 15:04:05", resolveTime)
		if err != nil {
			et = time.Now()
		}
	} else {
		et = time.Now()
	}
	d := et.Sub(st)
	days := int(d.Hours()) / 24
	hours := int(d.Hours()) % 24
	minutes := int(d.Minutes()) % 60
	if days > 0 {
		return fmt.Sprintf("%dd %dh %dm", days, hours, minutes)
	} else if hours > 0 {
		return fmt.Sprintf("%dh %dm", hours, minutes)
	}
	return fmt.Sprintf("%dm", minutes)
}

func (s *OrderStore) computeProcessTimes(ctx context.Context, proID string) (startTime, resolveTime, duration string) {
	var startTimeStr sql.NullString
	_ = s.db.QueryRowContext(ctx, `
SELECT json_extract(raw_json, '$.createTime')
FROM business_order_oper_logs
WHERE pro_id = ? AND json_extract(raw_json, '$.proTaskStateName') = '待处理（属地开发组分析）'
ORDER BY json_extract(raw_json, '$.createTime') ASC
LIMIT 1
`, proID).Scan(&startTimeStr)

	if !startTimeStr.Valid || startTimeStr.String == "" {
		return "", "", ""
	}

	startTime = startTimeStr.String
	st, err := time.Parse("2006-01-02 15:04:05", startTimeStr.String)
	if err != nil {
		return startTime, "", ""
	}

	var endTimeStr sql.NullString
	_ = s.db.QueryRowContext(ctx, `
SELECT json_extract(raw_json, '$.createTime')
FROM business_order_oper_logs
WHERE pro_id = ? AND json_extract(raw_json, '$.proTaskStateName') = '待处理（验证）'
ORDER BY json_extract(raw_json, '$.createTime') DESC
LIMIT 1
`, proID).Scan(&endTimeStr)

	var et time.Time
	if endTimeStr.Valid && endTimeStr.String != "" {
		resolveTime = endTimeStr.String
		et, err = time.Parse("2006-01-02 15:04:05", endTimeStr.String)
		if err != nil {
			resolveTime = ""
			et = time.Now()
		}
	} else {
		resolveTime = ""
		et = time.Now()
	}

	d := et.Sub(st)
	days := int(d.Hours()) / 24
	hours := int(d.Hours()) % 24
	minutes := int(d.Minutes()) % 60

	if days > 0 {
		duration = fmt.Sprintf("%dd %dh %dm", days, hours, minutes)
	} else if hours > 0 {
		duration = fmt.Sprintf("%dh %dm", hours, minutes)
	} else {
		duration = fmt.Sprintf("%dm", minutes)
	}
	return startTime, resolveTime, duration
}

func (s *OrderStore) backfillProcessTimes(ctx context.Context) error {
	rows, err := s.db.QueryContext(ctx, `SELECT pro_id FROM business_orders WHERE start_time = '' OR resolve_time = '' OR start_time IS NULL OR resolve_time IS NULL`)
	if err != nil {
		return err
	}
	defer rows.Close()

	var proIDs []string
	for rows.Next() {
		var proID string
		if err := rows.Scan(&proID); err != nil {
			return err
		}
		proIDs = append(proIDs, proID)
	}
	if err := rows.Err(); err != nil {
		return err
	}

	for _, proID := range proIDs {
		startTime, resolveTime, _ := s.computeProcessTimes(ctx, proID)
		if startTime == "" && resolveTime == "" {
			continue
		}
		_, err := s.db.ExecContext(ctx, `UPDATE business_orders SET start_time = ?, resolve_time = ? WHERE pro_id = ?`, startTime, resolveTime, proID)
		if err != nil {
			return err
		}
	}
	return nil
}

func (s *OrderStore) SaveOperLogs(ctx context.Context, proID string, logs []model.OperLogVo) error {
	if len(logs) == 0 {
		return nil
	}
	for _, log := range logs {
		if log.OperId == "" {
			continue
		}
		raw, err := json.Marshal(log)
		if err != nil {
			return err
		}
		_, err = s.db.ExecContext(ctx, `
INSERT OR IGNORE INTO business_order_oper_logs (pro_id, oper_id, raw_json)
VALUES (?, ?, ?)
`, proID, log.OperId, string(raw))
		if err != nil {
			return err
		}
	}
	return nil
}

func (s *OrderStore) SaveZenTaoProblem(ctx context.Context, proID string, problem model.ZenTaoProblem) error {
	raw, err := json.Marshal(problem)
	if err != nil {
		return err
	}
	_, err = s.db.ExecContext(ctx, `
INSERT OR REPLACE INTO business_order_zen_tao_problems (pro_id, raw_json)
VALUES (?, ?)
`, proID, string(raw))
	return err
}

func (s *OrderStore) ListOperLogs(ctx context.Context, proID string) ([]SavedOperLog, error) {
	rows, err := s.db.QueryContext(ctx, `
SELECT id, pro_id, oper_id, raw_json, created_at
FROM business_order_oper_logs
WHERE pro_id = ?
ORDER BY created_at ASC
`, proID)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	items := make([]SavedOperLog, 0)
	for rows.Next() {
		var item SavedOperLog
		var raw string
		if err := rows.Scan(&item.Id, &item.ProId, &item.OperId, &raw, &item.CreatedAt); err != nil {
			return nil, err
		}
		if err := json.Unmarshal([]byte(raw), &item.Raw); err != nil {
			return nil, err
		}
		items = append(items, item)
	}
	if err := rows.Err(); err != nil {
		return nil, err
	}
	return items, nil
}

func (s *OrderStore) GetZenTaoProblem(ctx context.Context, proID string) (*SavedZenTaoProblem, error) {
	var item SavedZenTaoProblem
	var raw string
	err := s.db.QueryRowContext(ctx, `
SELECT id, pro_id, raw_json, created_at
FROM business_order_zen_tao_problems
WHERE pro_id = ?
`, proID).Scan(&item.Id, &item.ProId, &raw, &item.CreatedAt)
	if err != nil {
		if errors.Is(err, sql.ErrNoRows) {
			return nil, nil
		}
		return nil, err
	}
	if err := json.Unmarshal([]byte(raw), &item.Raw); err != nil {
		return nil, err
	}
	return &item, nil
}

func (s *OrderStore) SaveChildList(ctx context.Context, parentProID string, children []model.ChildItem) error {
	if len(children) == 0 {
		return nil
	}
	_, err := s.db.ExecContext(ctx, `DELETE FROM business_order_children WHERE parent_pro_id = ?`, parentProID)
	if err != nil {
		return err
	}
	for _, child := range children {
		if child.ProId == "" {
			continue
		}
		_, err = s.db.ExecContext(ctx, `
INSERT OR IGNORE INTO business_order_children (pro_id, parent_pro_id, remote_id)
VALUES (?, ?, ?)
`, child.ProId, parentProID, child.Id)
		if err != nil {
			return err
		}
	}
	return nil
}

func (s *OrderStore) UpdateExternalNo(ctx context.Context, proID string, externalNo string) error {
	_, err := s.db.ExecContext(ctx, `UPDATE business_orders SET external_no = ? WHERE pro_id = ?`, externalNo, proID)
	if err != nil {
		fmt.Println("UpdateExternalNo", err)
	}
	return err
}

func (s *OrderStore) ListChildItems(ctx context.Context, parentProID string) ([]model.ChildItem, error) {
	rows, err := s.db.QueryContext(ctx, `SELECT pro_id, parent_pro_id, remote_id FROM business_order_children WHERE parent_pro_id = ?`, parentProID)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	var items []model.ChildItem
	for rows.Next() {
		var item model.ChildItem
		if err := rows.Scan(&item.ProId, &item.ParentProId, &item.Id); err != nil {
			return nil, err
		}
		items = append(items, item)
	}
	if err := rows.Err(); err != nil {
		return nil, err
	}
	return items, nil
}

func (s *OrderStore) ListAllProIds(ctx context.Context) ([]string, error) {
	rows, err := s.db.QueryContext(ctx, `SELECT pro_id FROM business_orders ORDER BY pro_id`)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	ids := make([]string, 0)
	for rows.Next() {
		var id string
		if err := rows.Scan(&id); err != nil {
			return nil, err
		}
		ids = append(ids, id)
	}
	if err := rows.Err(); err != nil {
		return nil, err
	}
	return ids, nil
}

func (s *OrderStore) GetFlowTrend(ctx context.Context, taskStateName string, startTimeFrom string, startTimeTo string) ([]DailyCount, error) {
	var conditions []string
	var args []any
	args = append(args, taskStateName)

	if startTimeFrom != "" {
		conditions = append(conditions, "bo.start_time >= ?")
		args = append(args, startTimeFrom)
	}
	if startTimeTo != "" {
		conditions = append(conditions, "bo.start_time <= ?")
		args = append(args, startTimeTo)
	}

	joinFilter := ""
	if len(conditions) > 0 {
		joinFilter = " AND " + strings.Join(conditions, " AND ")
	}

	query := `SELECT day, COUNT(*) AS count FROM (
  SELECT DATE(MIN(json_extract(ol.raw_json, '$.createTime'))) AS day
  FROM business_order_oper_logs ol
  JOIN business_orders bo ON bo.pro_id = ol.pro_id
  WHERE json_extract(ol.raw_json, '$.proTaskStateName') = ?` + joinFilter + `
  GROUP BY ol.pro_id
) sub
GROUP BY day
ORDER BY day`

	rows, err := s.db.QueryContext(ctx, query, args...)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	items := make([]DailyCount, 0)
	for rows.Next() {
		var item DailyCount
		if err := rows.Scan(&item.Date, &item.Count); err != nil {
			return nil, err
		}
		items = append(items, item)
	}
	if err := rows.Err(); err != nil {
		return nil, err
	}
	return items, nil
}

func (s *OrderStore) GetResolveDurationDistribution(ctx context.Context, startTimeFrom string, startTimeTo string) ([]DurationBucket, error) {
	var conditions []string
	var args []any

	conditions = append(conditions, "start_time != ''")
	conditions = append(conditions, "resolve_time != ''")

	if startTimeFrom != "" {
		conditions = append(conditions, "start_time >= ?")
		args = append(args, startTimeFrom)
	}
	if startTimeTo != "" {
		conditions = append(conditions, "start_time <= ?")
		args = append(args, startTimeTo)
	}

	whereClause := "WHERE " + strings.Join(conditions, " AND ")

	query := `SELECT
  CASE
    WHEN (julianday(resolve_time) - julianday(start_time)) * 24 < 24 THEN '<24h'
    WHEN (julianday(resolve_time) - julianday(start_time)) * 24 < 48 THEN '24-48h'
    WHEN (julianday(resolve_time) - julianday(start_time)) * 24 < 120 THEN '48-120h'
    ELSE '>120h'
  END AS bucket,
  COUNT(*) AS count
FROM business_orders ` + whereClause + ` GROUP BY bucket ORDER BY bucket`

	rows, err := s.db.QueryContext(ctx, query, args...)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	items := make([]DurationBucket, 0)
	for rows.Next() {
		var item DurationBucket
		if err := rows.Scan(&item.Label, &item.Count); err != nil {
			return nil, err
		}
		items = append(items, item)
	}
	if err := rows.Err(); err != nil {
		return nil, err
	}
	return items, nil
}
