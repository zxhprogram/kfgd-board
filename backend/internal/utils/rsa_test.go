package utils

import (
	"backend/internal/model"
	"fmt"
	"testing"

	"resty.dev/v3"
)

func TestRSAEncryptDecryptAndSign(t *testing.T) {
	privateKey, publicKey, err := GetKeyPair()
	if err != nil {
		t.Fatal(err)
	}

	data := "hello openapi rsa 加密验签，包含超过 117 字节的长文本。hello openapi rsa 加密验签，包含超过 117 字节的长文本。"
	encrypted, err := Encrypt(data, publicKey)
	if err != nil {
		t.Fatal(err)
	}

	decrypted, err := Decrypt(encrypted, privateKey)
	if err != nil {
		t.Fatal(err)
	}
	if decrypted != data {
		t.Fatalf("decrypted data = %q, want %q", decrypted, data)
	}

	signature, err := Sign(data, privateKey)
	if err != nil {
		t.Fatal(err)
	}

	ok, err := Verify(data, publicKey, signature)
	if err != nil {
		t.Fatal(err)
	}
	if !ok {
		t.Fatal("signature verification failed")
	}

	ok, err = Verify(data+"changed", publicKey, signature)
	if err != nil {
		t.Fatal(err)
	}
	if ok {
		t.Fatal("signature verification unexpectedly passed")
	}
}

func TestRSAKeyStringRoundTrip(t *testing.T) {
	privateKey, publicKey, err := GetKeyPair()
	if err != nil {
		t.Fatal(err)
	}

	privateKeyText, err := EncodePrivateKey(privateKey)
	if err != nil {
		t.Fatal(err)
	}
	publicKeyText, err := EncodePublicKey(publicKey)
	if err != nil {
		t.Fatal(err)
	}

	parsedPrivateKey, err := GetPrivateKey(privateKeyText)
	if err != nil {
		t.Fatal(err)
	}
	parsedPublicKey, err := GetPublicKey(publicKeyText)
	if err != nil {
		t.Fatal(err)
	}

	data := "abc123"
	signature, err := SignWithKeyStrings(data, privateKeyText, publicKeyText)
	if err != nil {
		t.Fatal(err)
	}
	ok, err := Verify(data, parsedPublicKey, signature)
	if err != nil {
		t.Fatal(err)
	}
	if !ok {
		t.Fatal("signature verification failed")
	}

	encrypted, err := Encrypt(data, parsedPublicKey)
	if err != nil {
		t.Fatal(err)
	}
	decrypted, err := Decrypt(encrypted, parsedPrivateKey)
	if err != nil {
		t.Fatal(err)
	}
	if decrypted != data {
		t.Fatalf("decrypted data = %q, want %q", decrypted, data)
	}
}

func TestGenerateSign(t *testing.T) {
	got, err := GenerateSign(map[string]any{
		"name":  "alice",
		"age":   18,
		"sign":  "ignored",
		"empty": nil,
		"ids":   []int{1, 2},
	})
	if err != nil {
		t.Fatal(err)
	}

	want := "age=18&name=alice"
	if got != want {
		t.Fatalf("GenerateSign() = %q, want %q", got, want)
	}
}

type OrderItem struct {
	CreateTime   string `json:"create_time"`
	Province     string `json:"province"`
	ProType      string `json:"proType"`
	PageSize     int    `json:"pageSize"`
	PageNum      int    `json:"pageNum"`
	SystemSource string `json:"systemSource"`
	Sign         string `json:"sign"`
}

func TestAAA(t *testing.T) {
	var order model.BusinessOrder
	client := resty.New()
	_, _ = client.R().SetHeaders(map[string]string{
		"Content-Type":  "application/x-www-form-urlencoded",
		"Authorization": "bearer e284f681-61b9-4443-801a-eb0ad0278eba",
	}).SetFormData(map[string]string{
		"proId":      "360000202603300932016890",
		"systemType": "yunguan",
		"pageSize":   "10",
		"pageNo":     "1",
	}).SetResult(&order).Post("https://kfgdui-prd.chinatowercom.cn:8300/api/problem/problemYg/list")
	fmt.Println(order)
}
