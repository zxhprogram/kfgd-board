package store

import (
	"context"
	"database/sql"
	"path/filepath"
	"testing"

	"backend/internal/model"

	_ "modernc.org/sqlite"
)

func TestOrderStoreUpsertAndList(t *testing.T) {
	store, err := OpenOrderStore(filepath.Join(t.TempDir(), "test.db"))
	if err != nil {
		t.Fatal(err)
	}
	defer store.Close()

	ctx := context.Background()
	if err := store.UpsertOrders(ctx, []model.BusinessOrderValue{
		{ProId: "p1", ExternalNo: "ext1", ProTitle: "title1", CustomerName: "alice", CustomerPhone: "10086", ProState: 1, CreateTime: "2026-01-01", UpdateTime: "2026-01-02"},
		{ProId: "p2", ExternalNo: "", ProTitle: "title2", CustomerName: "bob", CustomerPhone: "10010", ProState: 2, CreateTime: "2026-02-01", UpdateTime: "2026-02-02"},
	}); err != nil {
		t.Fatal(err)
	}

	items, total, err := store.ListOrders(ctx, 1, 1)
	if err != nil {
		t.Fatal(err)
	}
	if total != 2 {
		t.Fatalf("total = %d, want 2", total)
	}
	if len(items) != 1 {
		t.Fatalf("len(items) = %d, want 1", len(items))
	}

	if err := store.UpsertOrders(ctx, []model.BusinessOrderValue{{ProId: "p1", ExternalNo: "ext-updated", ProTitle: "updated", CustomerName: "alice"}}); err != nil {
		t.Fatal(err)
	}
	items, total, err = store.ListOrders(ctx, 1, 10)
	if err != nil {
		t.Fatal(err)
	}
	if total != 2 {
		t.Fatalf("total after upsert = %d, want 2", total)
	}

	found := false
	for _, item := range items {
		if item.ProId == "p1" {
			found = true
			if item.ProTitle != "updated" || item.ExternalNo != "ext-updated" || item.Raw.ProTitle != "updated" || item.Raw.ExternalNo != "ext-updated" {
				t.Fatalf("updated item = %+v", item)
			}
		}
	}
	if !found {
		t.Fatal("updated order not found")
	}
}

func TestOrderStoreMigratesExternalNoColumn(t *testing.T) {
	dbPath := filepath.Join(t.TempDir(), "old.db")
	db, err := sql.Open("sqlite", dbPath)
	if err != nil {
		t.Fatal(err)
	}
	_, err = db.Exec(`
CREATE TABLE business_orders (
	pro_id TEXT PRIMARY KEY,
	pro_title TEXT,
	customer_name TEXT,
	customer_phone TEXT,
	pro_state INTEGER,
	create_time TEXT,
	update_time TEXT,
	raw_json TEXT NOT NULL,
	saved_at DATETIME DEFAULT CURRENT_TIMESTAMP
)`)
	if err != nil {
		t.Fatal(err)
	}
	if err := db.Close(); err != nil {
		t.Fatal(err)
	}

	store, err := OpenOrderStore(dbPath)
	if err != nil {
		t.Fatal(err)
	}
	defer store.Close()

	if err := store.UpsertOrders(context.Background(), []model.BusinessOrderValue{{ProId: "p1", ExternalNo: "ext1"}}); err != nil {
		t.Fatal(err)
	}
	items, total, err := store.ListOrders(context.Background(), 1, 10)
	if err != nil {
		t.Fatal(err)
	}
	if total != 1 || len(items) != 1 || items[0].ExternalNo != "ext1" {
		t.Fatalf("items = %+v, total = %d", items, total)
	}
}
