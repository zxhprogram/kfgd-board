package handler

import (
	"context"
	"encoding/json"
	"net/http"
	"strconv"
	"strings"

	"backend/internal/model"
	"backend/internal/store"
)

type BusinessOrderFetcher interface {
	FetchByProID(ctx context.Context, proID string) ([]model.BusinessOrderValue, error)
}

type BusinessOrderStore interface {
	UpsertOrders(ctx context.Context, values []model.BusinessOrderValue) error
	ListOrders(ctx context.Context, pageNo int, pageSize int) ([]store.SavedBusinessOrder, int, error)
}

type BusinessOrderHandler struct {
	fetcher BusinessOrderFetcher
	store   BusinessOrderStore
}

type importBusinessOrdersRequest struct {
	Orders []importBusinessOrderItem `json:"orders"`
	ProIDs []string                  `json:"proIds"`
}

type importBusinessOrderItem struct {
	ProID      string `json:"proId"`
	ExternalNo string `json:"externalNo"`
}

func NewBusinessOrderHandler(fetcher BusinessOrderFetcher, store BusinessOrderStore) *BusinessOrderHandler {
	return &BusinessOrderHandler{fetcher: fetcher, store: store}
}

func (h *BusinessOrderHandler) Import(w http.ResponseWriter, r *http.Request) {
	var req importBusinessOrdersRequest
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		writeJSONError(w, http.StatusBadRequest, "invalid request body")
		return
	}

	orders := normalizeImportOrders(req)
	if len(orders) == 0 {
		writeJSONError(w, http.StatusBadRequest, "orders is required")
		return
	}

	values := make([]model.BusinessOrderValue, 0)
	for _, order := range orders {
		items, err := h.fetcher.FetchByProID(r.Context(), order.ProID)
		if err != nil {
			writeJSONError(w, http.StatusBadGateway, err.Error())
			return
		}
		for i := range items {
			items[i].ExternalNo = order.ExternalNo
		}
		values = append(values, items...)
	}

	if err := h.store.UpsertOrders(r.Context(), values); err != nil {
		writeJSONError(w, http.StatusInternalServerError, err.Error())
		return
	}

	writeJSON(w, http.StatusOK, map[string]any{
		"requested": len(orders),
		"imported":  len(values),
	})
}

func (h *BusinessOrderHandler) List(w http.ResponseWriter, r *http.Request) {
	pageNo := parsePositiveInt(r.URL.Query().Get("pageNo"), 1)
	pageSize := parsePositiveInt(r.URL.Query().Get("pageSize"), 10)
	if pageSize > 100 {
		pageSize = 100
	}

	items, total, err := h.store.ListOrders(r.Context(), pageNo, pageSize)
	if err != nil {
		writeJSONError(w, http.StatusInternalServerError, err.Error())
		return
	}

	writeJSON(w, http.StatusOK, map[string]any{
		"items":    items,
		"pageNo":   pageNo,
		"pageSize": pageSize,
		"total":    total,
	})
}

func normalizeImportOrders(req importBusinessOrdersRequest) []importBusinessOrderItem {
	seen := make(map[string]struct{}, len(req.Orders)+len(req.ProIDs))
	result := make([]importBusinessOrderItem, 0, len(req.Orders)+len(req.ProIDs))
	for _, order := range req.Orders {
		proID := strings.TrimSpace(order.ProID)
		if proID == "" {
			continue
		}
		if _, ok := seen[proID]; ok {
			continue
		}
		seen[proID] = struct{}{}
		result = append(result, importBusinessOrderItem{
			ProID:      proID,
			ExternalNo: strings.TrimSpace(order.ExternalNo),
		})
	}
	for _, proID := range req.ProIDs {
		proID = strings.TrimSpace(proID)
		if proID == "" {
			continue
		}
		if _, ok := seen[proID]; ok {
			continue
		}
		seen[proID] = struct{}{}
		result = append(result, importBusinessOrderItem{ProID: proID})
	}
	return result
}

func parsePositiveInt(value string, fallback int) int {
	parsed, err := strconv.Atoi(value)
	if err != nil || parsed < 1 {
		return fallback
	}
	return parsed
}

func writeJSON(w http.ResponseWriter, status int, body any) {
	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(status)
	_ = json.NewEncoder(w).Encode(body)
}

func writeJSONError(w http.ResponseWriter, status int, message string) {
	writeJSON(w, status, map[string]string{"error": message})
}
