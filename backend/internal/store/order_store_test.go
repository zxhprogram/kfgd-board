package store

import (
	"context"
	"path/filepath"
	"testing"

	"backend/internal/model"
)

func TestOrderStoreUpsertAndList(t *testing.T) {
	store, err := OpenOrderStore(filepath.Join(t.TempDir(), "test.db"))
	if err != nil {
		t.Fatal(err)
	}
	defer store.Close()

	ctx := context.Background()
	if err := store.UpsertOrders(ctx, []model.BusinessOrderValue{
		{ProId: "p1", ProTitle: "title1", CustomerName: "alice", CustomerPhone: "10086", ProState: 1, CreateTime: "2026-01-01", UpdateTime: "2026-01-02"},
		{ProId: "p2", ProTitle: "title2", CustomerName: "bob", CustomerPhone: "10010", ProState: 2, CreateTime: "2026-02-01", UpdateTime: "2026-02-02"},
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

	if err := store.UpsertOrders(ctx, []model.BusinessOrderValue{{ProId: "p1", ProTitle: "updated", CustomerName: "alice"}}); err != nil {
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
			if item.ProTitle != "updated" || item.Raw.ProTitle != "updated" {
				t.Fatalf("updated item = %+v", item)
			}
		}
	}
	if !found {
		t.Fatal("updated order not found")
	}
}
