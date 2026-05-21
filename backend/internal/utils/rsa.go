package utils

import (
	"bytes"
	"crypto"
	"crypto/rand"
	"crypto/rsa"
	"crypto/sha1"
	"crypto/x509"
	"encoding/base64"
	"errors"
	"fmt"
	"reflect"
	"sort"
	"strings"
)

const (
	maxEncryptBlock = 117
	maxDecryptBlock = 128
)

func GetKeyPair() (*rsa.PrivateKey, *rsa.PublicKey, error) {
	privateKey, err := rsa.GenerateKey(rand.Reader, 1024)
	if err != nil {
		return nil, nil, err
	}
	return privateKey, &privateKey.PublicKey, nil
}

func GetPrivateKey(privateKey string) (*rsa.PrivateKey, error) {
	decodedKey, err := base64.StdEncoding.DecodeString(privateKey)
	if err != nil {
		return nil, err
	}
	key, err := x509.ParsePKCS8PrivateKey(decodedKey)
	if err != nil {
		return nil, err
	}
	rsaKey, ok := key.(*rsa.PrivateKey)
	if !ok {
		return nil, errors.New("private key is not RSA")
	}
	return rsaKey, nil
}

func GetPublicKey(publicKey string) (*rsa.PublicKey, error) {
	decodedKey, err := base64.StdEncoding.DecodeString(publicKey)
	if err != nil {
		return nil, err
	}
	key, err := x509.ParsePKIXPublicKey(decodedKey)
	if err != nil {
		return nil, err
	}
	rsaKey, ok := key.(*rsa.PublicKey)
	if !ok {
		return nil, errors.New("public key is not RSA")
	}
	return rsaKey, nil
}

func EncodePrivateKey(privateKey *rsa.PrivateKey) (string, error) {
	derBytes, err := x509.MarshalPKCS8PrivateKey(privateKey)
	if err != nil {
		return "", err
	}
	return base64.StdEncoding.EncodeToString(derBytes), nil
}

func EncodePublicKey(publicKey *rsa.PublicKey) (string, error) {
	derBytes, err := x509.MarshalPKIXPublicKey(publicKey)
	if err != nil {
		return "", err
	}
	return base64.StdEncoding.EncodeToString(derBytes), nil
}

func Encrypt(data string, publicKey *rsa.PublicKey) (string, error) {
	dataBytes := []byte(data)
	var out bytes.Buffer

	for offset := 0; offset < len(dataBytes); offset += maxEncryptBlock {
		end := offset + maxEncryptBlock
		if end > len(dataBytes) {
			end = len(dataBytes)
		}
		cache, err := rsa.EncryptPKCS1v15(rand.Reader, publicKey, dataBytes[offset:end])
		if err != nil {
			return "", err
		}
		out.Write(cache)
	}

	return base64.StdEncoding.EncodeToString(out.Bytes()), nil
}

func Decrypt(data string, privateKey *rsa.PrivateKey) (string, error) {
	dataBytes, err := base64.StdEncoding.DecodeString(data)
	if err != nil {
		return "", err
	}
	var out bytes.Buffer

	for offset := 0; offset < len(dataBytes); offset += maxDecryptBlock {
		end := offset + maxDecryptBlock
		if end > len(dataBytes) {
			end = len(dataBytes)
		}
		cache, err := rsa.DecryptPKCS1v15(rand.Reader, privateKey, dataBytes[offset:end])
		if err != nil {
			return "", err
		}
		out.Write(cache)
	}

	return out.String(), nil
}

func SignWithKeyStrings(data string, privateKey string, publicKey string) (string, error) {
	key, err := GetPrivateKey(privateKey)
	if err != nil {
		return "", err
	}
	if publicKey != "" {
		if _, err := GetPublicKey(publicKey); err != nil {
			return "", err
		}
	}
	return Sign(data, key)
}

func Sign(data string, privateKey *rsa.PrivateKey) (string, error) {
	hash := sha1.Sum([]byte(data))
	signature, err := rsa.SignPKCS1v15(rand.Reader, privateKey, crypto.SHA1, hash[:])
	if err != nil {
		return "", err
	}
	return base64.StdEncoding.EncodeToString(signature), nil
}

func Verify(srcData string, publicKey *rsa.PublicKey, sign string) (bool, error) {
	signature, err := base64.StdEncoding.DecodeString(sign)
	if err != nil {
		return false, err
	}
	hash := sha1.Sum([]byte(srcData))
	if err := rsa.VerifyPKCS1v15(publicKey, crypto.SHA1, hash[:], signature); err != nil {
		return false, nil
	}
	return true, nil
}

func GenerateSign(params map[string]any) (string, error) {
	keys := make([]string, 0, len(params))
	for key := range params {
		keys = append(keys, key)
	}
	sort.Strings(keys)

	parts := make([]string, 0, len(keys))
	for _, key := range keys {
		value := params[key]
		if key == "sign" || value == nil || isArray(value) {
			continue
		}
		parts = append(parts, fmt.Sprintf("%s=%v", key, value))
	}
	if len(parts) == 0 {
		return "", nil
	}
	return strings.Join(parts, "&"), nil
}

func isArray(value any) bool {
	kind := reflect.TypeOf(value).Kind()
	return kind == reflect.Array || kind == reflect.Slice
}
