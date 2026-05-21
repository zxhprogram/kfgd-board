package client

import (
	"context"
	"encoding/json"
	"net/http"
	"net/http/httptest"
	"testing"
)

func TestBusinessOrderClientFetchByProID(t *testing.T) {
	server := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		if r.Method != http.MethodPost {
			t.Fatalf("method = %s, want POST", r.Method)
		}
		if got := r.Header.Get("Authorization"); got != "bearer test" {
			t.Fatalf("authorization = %q, want bearer test", got)
		}
		if err := r.ParseForm(); err != nil {
			t.Fatal(err)
		}
		if got := r.Form.Get("proId"); got != "p1" {
			t.Fatalf("proId = %q, want p1", got)
		}
		if got := r.Form.Get("systemType"); got != "yunguan" {
			t.Fatalf("systemType = %q, want yunguan", got)
		}

		_ = json.NewEncoder(w).Encode(map[string]any{
			"resultStat": "1",
			"mess":       "success",
			"data": map[string]any{
				"values": []map[string]any{{"proId": "p1", "proTitle": "title1"}},
				"pagenation": map[string]any{
					"pageSize":  10,
					"pageNo":    1,
					"itemCount": 1,
					"pageCount": 1,
				},
			},
		})
	}))
	defer server.Close()

	client, err := NewBusinessOrderClient(server.URL, "bearer test")
	if err != nil {
		t.Fatal(err)
	}
	defer client.Close()

	values, err := client.FetchByProID(context.Background(), "p1")
	if err != nil {
		t.Fatal(err)
	}
	if len(values) != 1 || values[0].ProId != "p1" || values[0].ProTitle != "title1" {
		t.Fatalf("values = %+v", values)
	}
}
