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

	log.Println("server listening on :8080")
	if err := http.ListenAndServe(":8080", mux); err != nil {
		log.Fatal(err)
	}
}
