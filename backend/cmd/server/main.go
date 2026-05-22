package main

import (
	"log"
	"net/http"

	"backend/internal/client"
	"backend/internal/handler"
	"backend/internal/store"
)

func main() {
	orderStore, err := store.OpenOrderStore("")
	if err != nil {
		log.Fatal(err)
	}
	defer orderStore.Close()

	orderClient, err := client.NewBusinessOrderClient("", "")
	if err != nil {
		log.Fatal(err)
	}
	defer orderClient.Close()

	businessOrderHandler := handler.NewBusinessOrderHandler(orderClient, orderStore)

	mux := http.NewServeMux()
	mux.HandleFunc("GET /health", handler.Health)
	mux.HandleFunc("POST /business-orders/import", businessOrderHandler.Import)
	mux.HandleFunc("GET /business-orders", businessOrderHandler.List)
	mux.HandleFunc("GET /business-orders/{proId}/oper-logs", businessOrderHandler.OperLogs)
	mux.HandleFunc("GET /business-orders/{proId}/zen-tao-problem", businessOrderHandler.ZenTaoProblem)

	log.Println("server listening on :8080")
	if err := http.ListenAndServe(":8080", withCORS(mux)); err != nil {
		log.Fatal(err)
	}
}

func withCORS(next http.Handler) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		w.Header().Set("Access-Control-Allow-Origin", "*")
		w.Header().Set("Access-Control-Allow-Methods", "GET, POST, OPTIONS")
		w.Header().Set("Access-Control-Allow-Headers", "Content-Type, Authorization")
		if r.Method == http.MethodOptions {
			w.WriteHeader(http.StatusNoContent)
			return
		}
		next.ServeHTTP(w, r)
	})
}
