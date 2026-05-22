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

type BusinessOrderDetailFetcher interface {
	FetchDetail(ctx context.Context, proID string) (*model.BusinessOrderValue, error)
}

type BusinessOrderStore interface {
	UpsertOrders(ctx context.Context, values []model.BusinessOrderValue) error
	ListOrders(ctx context.Context, pageNo int, pageSize int, proIdFilter string) ([]store.SavedBusinessOrder, int, error)
	SaveOperLogs(ctx context.Context, proID string, logs []model.OperLogVo) error
	SaveZenTaoProblem(ctx context.Context, proID string, problem model.ZenTaoProblem) error
	ListOperLogs(ctx context.Context, proID string) ([]store.SavedOperLog, error)
	GetZenTaoProblem(ctx context.Context, proID string) (*store.SavedZenTaoProblem, error)
	GetFlowTrend(ctx context.Context, taskStateName string) ([]store.DailyCount, error)
}

type BusinessOrderHandler struct {
	fetcher BusinessOrderDetailFetcher
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

func NewBusinessOrderHandler(fetcher BusinessOrderDetailFetcher, store BusinessOrderStore) *BusinessOrderHandler {
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

	imported := 0
	for _, order := range orders {
		detail, err := h.fetcher.FetchDetail(r.Context(), order.ProID)
		if err != nil {
			writeJSONError(w, http.StatusBadGateway, err.Error())
			return
		}
		detail.ExternalNo = order.ExternalNo

		if err := h.store.UpsertOrders(r.Context(), []model.BusinessOrderValue{*detail}); err != nil {
			writeJSONError(w, http.StatusInternalServerError, err.Error())
			return
		}
		if err := h.store.SaveOperLogs(r.Context(), order.ProID, detail.OperLogVoList); err != nil {
			writeJSONError(w, http.StatusInternalServerError, err.Error())
			return
		}
		if err := h.store.SaveZenTaoProblem(r.Context(), order.ProID, detail.ZenTaoProblem); err != nil {
			writeJSONError(w, http.StatusInternalServerError, err.Error())
			return
		}
		imported++
	}

	writeJSON(w, http.StatusOK, map[string]any{
		"requested": len(orders),
		"imported":  imported,
	})
}

func (h *BusinessOrderHandler) List(w http.ResponseWriter, r *http.Request) {
	pageNo := parsePositiveInt(r.URL.Query().Get("pageNo"), 1)
	pageSize := parsePositiveInt(r.URL.Query().Get("pageSize"), 10)
	if pageSize > 100 {
		pageSize = 100
	}
	proIdFilter := r.URL.Query().Get("proId")

	items, total, err := h.store.ListOrders(r.Context(), pageNo, pageSize, proIdFilter)
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

func (h *BusinessOrderHandler) OperLogs(w http.ResponseWriter, r *http.Request) {
	proID := r.PathValue("proId")
	if proID == "" {
		writeJSONError(w, http.StatusBadRequest, "proId is required")
		return
	}

	items, err := h.store.ListOperLogs(r.Context(), proID)
	if err != nil {
		writeJSONError(w, http.StatusInternalServerError, err.Error())
		return
	}

	writeJSON(w, http.StatusOK, map[string]any{
		"proId": proID,
		"items": items,
	})
}

func (h *BusinessOrderHandler) ZenTaoProblem(w http.ResponseWriter, r *http.Request) {
	proID := r.PathValue("proId")
	if proID == "" {
		writeJSONError(w, http.StatusBadRequest, "proId is required")
		return
	}

	item, err := h.store.GetZenTaoProblem(r.Context(), proID)
	if err != nil {
		writeJSONError(w, http.StatusInternalServerError, err.Error())
		return
	}

	writeJSON(w, http.StatusOK, map[string]any{
		"proId": proID,
		"item":  item,
	})
}

func (h *BusinessOrderHandler) FlowTrend(w http.ResponseWriter, r *http.Request) {
	taskStateName := r.URL.Query().Get("taskStateName")
	if taskStateName == "" {
		taskStateName = "待处理（属地开发组分析）"
	}

	items, err := h.store.GetFlowTrend(r.Context(), taskStateName)
	if err != nil {
		writeJSONError(w, http.StatusInternalServerError, err.Error())
		return
	}

	writeJSON(w, http.StatusOK, map[string]any{
		"taskStateName": taskStateName,
		"items":         items,
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
