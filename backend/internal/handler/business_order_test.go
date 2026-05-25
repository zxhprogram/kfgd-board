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

type fakeBusinessOrderDetailFetcher struct {
	values map[string]*model.BusinessOrderValue
}

func (f fakeBusinessOrderDetailFetcher) FetchDetail(ctx context.Context, proID string) (*model.BusinessOrderValue, error) {
	if v, ok := f.values[proID]; ok {
		return v, nil
	}
	return &model.BusinessOrderValue{ProId: proID}, nil
}

type fakeBusinessOrderStore struct {
	values      []model.BusinessOrderValue
	operLogs    map[string][]model.OperLogVo
	zenTaoProbs map[string]model.ZenTaoProblem
	childLists  map[string][]model.ChildItem
}

func newFakeBusinessOrderStore() *fakeBusinessOrderStore {
	return &fakeBusinessOrderStore{
		operLogs:    make(map[string][]model.OperLogVo),
		zenTaoProbs: make(map[string]model.ZenTaoProblem),
		childLists:  make(map[string][]model.ChildItem),
	}
}

func (s *fakeBusinessOrderStore) UpsertOrders(ctx context.Context, values []model.BusinessOrderValue) error {
	s.values = append(s.values, values...)
	return nil
}

func (s *fakeBusinessOrderStore) ListOrders(ctx context.Context, pageNo int, pageSize int, proIdFilter string) ([]store.SavedBusinessOrder, int, error) {
	items := []store.SavedBusinessOrder{{ProId: "p1", ProTitle: "title1"}}
	return items, 1, nil
}

func (s *fakeBusinessOrderStore) SaveOperLogs(ctx context.Context, proID string, logs []model.OperLogVo) error {
	s.operLogs[proID] = append(s.operLogs[proID], logs...)
	return nil
}

func (s *fakeBusinessOrderStore) SaveZenTaoProblem(ctx context.Context, proID string, problem model.ZenTaoProblem) error {
	s.zenTaoProbs[proID] = problem
	return nil
}

func (s *fakeBusinessOrderStore) ListOperLogs(ctx context.Context, proID string) ([]store.SavedOperLog, error) {
	return nil, nil
}

func (s *fakeBusinessOrderStore) GetZenTaoProblem(ctx context.Context, proID string) (*store.SavedZenTaoProblem, error) {
	return nil, nil
}

func (s *fakeBusinessOrderStore) GetFlowTrend(ctx context.Context, taskStateName string) ([]store.DailyCount, error) {
	return nil, nil
}

func (s *fakeBusinessOrderStore) ListAllProIds(ctx context.Context) ([]string, error) {
	return nil, nil
}

func (s *fakeBusinessOrderStore) SaveChildList(ctx context.Context, parentProID string, children []model.ChildItem) error {
	s.childLists[parentProID] = children
	return nil
}

func TestBusinessOrderHandlerImport(t *testing.T) {
	store := newFakeBusinessOrderStore()
	handler := NewBusinessOrderHandler(fakeBusinessOrderDetailFetcher{values: map[string]*model.BusinessOrderValue{
		"p1": {ProId: "p1", ProTitle: "title1", OperLogVoList: []model.OperLogVo{{OperId: "o1", ProId: "p1"}}, ZenTaoProblem: model.ZenTaoProblem{ParentCode: "p1"}},
	}}, store)

	req := httptest.NewRequest(http.MethodPost, "/business-orders/import", bytes.NewBufferString(`{"orders":[{"proId":"p1","externalNo":"ext1"},{"proId":"p1","externalNo":"ignored"},{"proId":"","externalNo":"empty"}]}`))
	w := httptest.NewRecorder()
	handler.Import(w, req)

	if w.Code != http.StatusOK {
		t.Fatalf("status = %d, body = %s", w.Code, w.Body.String())
	}
	if len(store.values) != 1 || store.values[0].ProId != "p1" || store.values[0].ExternalNo != "ext1" {
		t.Fatalf("stored values = %+v", store.values)
	}
	if len(store.operLogs["p1"]) != 1 || store.operLogs["p1"][0].OperId != "o1" {
		t.Fatalf("oper logs = %+v", store.operLogs)
	}
	if store.zenTaoProbs["p1"].ParentCode != "p1" {
		t.Fatalf("zen tao problem = %+v", store.zenTaoProbs)
	}

	var body map[string]int
	if err := json.NewDecoder(w.Body).Decode(&body); err != nil {
		t.Fatal(err)
	}
	if body["requested"] != 1 || body["imported"] != 1 {
		t.Fatalf("body = %+v", body)
	}
}

func TestBusinessOrderHandlerImportLegacyProIDs(t *testing.T) {
	store := newFakeBusinessOrderStore()
	handler := NewBusinessOrderHandler(fakeBusinessOrderDetailFetcher{values: map[string]*model.BusinessOrderValue{
		"p1": {ProId: "p1", ProTitle: "title1"},
	}}, store)

	req := httptest.NewRequest(http.MethodPost, "/business-orders/import", bytes.NewBufferString(`{"proIds":["p1","p1",""]}`))
	w := httptest.NewRecorder()
	handler.Import(w, req)

	if w.Code != http.StatusOK {
		t.Fatalf("status = %d, body = %s", w.Code, w.Body.String())
	}
	if len(store.values) != 1 || store.values[0].ProId != "p1" || store.values[0].ExternalNo != "" {
		t.Fatalf("stored values = %+v", store.values)
	}
}

func TestBusinessOrderHandlerList(t *testing.T) {
	handler := NewBusinessOrderHandler(fakeBusinessOrderDetailFetcher{}, newFakeBusinessOrderStore())
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
