package handler

import (
	"context"
	"encoding/json"
	"fmt"
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
	ListOrders(ctx context.Context, pageNo int, pageSize int, proIdFilter string, proState *int, startTimeFrom string, startTimeTo string, resolveTimeFrom string, resolveTimeTo string) ([]store.SavedBusinessOrder, int, error)
	SaveOperLogs(ctx context.Context, proID string, logs []model.OperLogVo) error
	SaveZenTaoProblem(ctx context.Context, proID string, problem model.ZenTaoProblem) error
	ListOperLogs(ctx context.Context, proID string) ([]store.SavedOperLog, error)
	GetZenTaoProblem(ctx context.Context, proID string) (*store.SavedZenTaoProblem, error)
	GetFlowTrend(ctx context.Context, taskStateName string, startTimeFrom string, startTimeTo string) ([]store.DailyCount, error)
	ListAllProIds(ctx context.Context) ([]string, error)
	SaveChildList(ctx context.Context, parentProID string, children []model.ChildItem) error
	ListChildItems(ctx context.Context, parentProID string) ([]model.ChildItem, error)
	UpdateExternalNo(ctx context.Context, proID string, externalNo string) error
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
		if err := h.store.SaveChildList(r.Context(), order.ProID, detail.ChildList); err != nil {
			writeJSONError(w, http.StatusInternalServerError, err.Error())
			return
		}
		if err := h.updateExternalNoFromChildren(r.Context(), order.ProID, detail.ChildList); err != nil {
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

	var proState *int
	if v := r.URL.Query().Get("proState"); v != "" {
		if parsed, err := strconv.Atoi(v); err == nil {
			proState = &parsed
		}
	}
	startTimeFrom := r.URL.Query().Get("startTimeFrom")
	startTimeTo := r.URL.Query().Get("startTimeTo")
	resolveTimeFrom := r.URL.Query().Get("resolveTimeFrom")
	resolveTimeTo := r.URL.Query().Get("resolveTimeTo")

	items, total, err := h.store.ListOrders(r.Context(), pageNo, pageSize, proIdFilter, proState, startTimeFrom, startTimeTo, resolveTimeFrom, resolveTimeTo)
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
	startTimeFrom := r.URL.Query().Get("startTimeFrom")
	startTimeTo := r.URL.Query().Get("startTimeTo")

	items, err := h.store.GetFlowTrend(r.Context(), taskStateName, startTimeFrom, startTimeTo)
	if err != nil {
		writeJSONError(w, http.StatusInternalServerError, err.Error())
		return
	}

	writeJSON(w, http.StatusOK, map[string]any{
		"taskStateName": taskStateName,
		"items":         items,
	})
}

func (h *BusinessOrderHandler) Sync(w http.ResponseWriter, r *http.Request) {
	pageNo := parsePositiveInt(r.URL.Query().Get("pageNo"), 1)
	pageSize := parsePositiveInt(r.URL.Query().Get("pageSize"), 50)

	allIds, err := h.store.ListAllProIds(r.Context())
	if err != nil {
		fmt.Printf("[Sync] ListAllProIds failed: %v\n", err)
		writeJSONError(w, http.StatusInternalServerError, err.Error())
		return
	}

	total := len(allIds)
	offset := (pageNo - 1) * pageSize
	if offset >= total {
		writeJSON(w, http.StatusOK, map[string]any{
			"synced": 0,
			"total":  total,
		})
		return
	}

	end := offset + pageSize
	if end > total {
		end = total
	}
	batch := allIds[offset:end]
	fmt.Printf("[Sync] batch pageNo=%d pageSize=%d total=%d batchStart=%d batchEnd=%d\n", pageNo, pageSize, total, offset, end)

	synced := 0
	for i, proID := range batch {
		detail, err := h.fetcher.FetchDetail(r.Context(), proID)
		if err != nil {
			fmt.Printf("[Sync] [%d/%d] FetchDetail failed proId=%s: %v\n", i+1, len(batch), proID, err)
			continue
		}
		_ = h.updateExternalNoFromChildren(r.Context(), proID, detail.ChildList)
		if err := h.store.UpsertOrders(r.Context(), []model.BusinessOrderValue{*detail}); err != nil {
			fmt.Printf("[Sync] [%d/%d] UpsertOrders failed proId=%s: %v\n", i+1, len(batch), proID, err)
			continue
		}
		if err := h.store.SaveOperLogs(r.Context(), proID, detail.OperLogVoList); err != nil {
			fmt.Printf("[Sync] [%d/%d] SaveOperLogs failed proId=%s: %v\n", i+1, len(batch), proID, err)
			continue
		}
		if err := h.store.SaveZenTaoProblem(r.Context(), proID, detail.ZenTaoProblem); err != nil {
			fmt.Printf("[Sync] [%d/%d] SaveZenTaoProblem failed proId=%s: %v\n", i+1, len(batch), proID, err)
			continue
		}
		if err := h.store.SaveChildList(r.Context(), proID, detail.ChildList); err != nil {
			fmt.Printf("[Sync] [%d/%d] SaveChildList failed proId=%s: %v\n", i+1, len(batch), proID, err)
			continue
		}
		synced++
	}

	fmt.Printf("[Sync] completed synced=%d total=%d\n", synced, total)
	writeJSON(w, http.StatusOK, map[string]any{
		"synced": synced,
		"total":  total,
	})
}

func (h *BusinessOrderHandler) updateExternalNoFromChildren(ctx context.Context, parentProID string, childList []model.ChildItem) error {
	if len(childList) == 0 {
		return nil
	}
	fmt.Printf("[updateExternalNo] parentProId=%s childCount=%d\n", parentProID, len(childList))
	var bugIds []string
	for _, child := range childList {
		if child.ProId == "" {
			continue
		}
		detail, err := h.fetcher.FetchDetail(ctx, child.ProId)
		if err != nil {
			fmt.Printf("[updateExternalNo] FetchDetail failed parentProId=%s childProId=%s: %v\n", parentProID, child.ProId, err)
			continue
		}
		if detail.ZenTaoProblem.BugId != "" {
			bugIds = append(bugIds, detail.ZenTaoProblem.BugId)
		}
	}
	if len(bugIds) == 0 {
		fmt.Printf("[updateExternalNo] no bugIds found parentProId=%s\n", parentProID)
		return nil
	}
	externalNo := strings.Join(bugIds, ",")
	fmt.Printf("[updateExternalNo] updating parentProId=%s externalNo=%s\n", parentProID, externalNo)
	return h.store.UpdateExternalNo(ctx, parentProID, externalNo)
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
