package handler

import (
	"bytes"
	"context"
	"encoding/json"
	"net/http"
	"net/http/httptest"
	"testing"

	"backend/internal/model"
	"backend/internal/store"
)

type fakeBusinessOrderFetcher struct {
	values map[string][]model.BusinessOrderValue
}

func (f fakeBusinessOrderFetcher) FetchByProID(ctx context.Context, proID string) ([]model.BusinessOrderValue, error) {
	return f.values[proID], nil
}

type fakeBusinessOrderStore struct {
	values []model.BusinessOrderValue
}

func (s *fakeBusinessOrderStore) UpsertOrders(ctx context.Context, values []model.BusinessOrderValue) error {
	s.values = append(s.values, values...)
	return nil
}

func (s *fakeBusinessOrderStore) ListOrders(ctx context.Context, pageNo int, pageSize int) ([]store.SavedBusinessOrder, int, error) {
	items := []store.SavedBusinessOrder{{ProId: "p1", ProTitle: "title1"}}
	return items, 1, nil
}

func TestBusinessOrderHandlerImport(t *testing.T) {
	store := &fakeBusinessOrderStore{}
	handler := NewBusinessOrderHandler(fakeBusinessOrderFetcher{values: map[string][]model.BusinessOrderValue{
		"p1": {{ProId: "p1", ProTitle: "title1"}},
	}}, store)

	req := httptest.NewRequest(http.MethodPost, "/business-orders/import", bytes.NewBufferString(`{"proIds":["p1","p1",""]}`))
	w := httptest.NewRecorder()
	handler.Import(w, req)

	if w.Code != http.StatusOK {
		t.Fatalf("status = %d, body = %s", w.Code, w.Body.String())
	}
	if len(store.values) != 1 || store.values[0].ProId != "p1" {
		t.Fatalf("stored values = %+v", store.values)
	}

	var body map[string]int
	if err := json.NewDecoder(w.Body).Decode(&body); err != nil {
		t.Fatal(err)
	}
	if body["requested"] != 1 || body["imported"] != 1 {
		t.Fatalf("body = %+v", body)
	}
}

func TestBusinessOrderHandlerList(t *testing.T) {
	handler := NewBusinessOrderHandler(fakeBusinessOrderFetcher{}, &fakeBusinessOrderStore{})
	req := httptest.NewRequest(http.MethodGet, "/business-orders?pageNo=1&pageSize=200", nil)
	w := httptest.NewRecorder()
	handler.List(w, req)

	if w.Code != http.StatusOK {
		t.Fatalf("status = %d, body = %s", w.Code, w.Body.String())
	}
	var body struct {
		PageSize int `json:"pageSize"`
		Total    int `json:"total"`
		Items    []store.SavedBusinessOrder
	}
	if err := json.NewDecoder(w.Body).Decode(&body); err != nil {
		t.Fatal(err)
	}
	if body.PageSize != 100 || body.Total != 1 || len(body.Items) != 1 {
		t.Fatalf("body = %+v", body)
	}
}
