package client

import (
	"context"
	"encoding/json"
	"errors"
	"fmt"
	"net/http"
	"os"

	"backend/internal/model"

	"resty.dev/v3"
)

type BusinessOrderClient struct {
	client        *resty.Client
	url           string
	authorization string
}

func NewBusinessOrderClient(url string, authorization string) (*BusinessOrderClient, error) {
	if url == "" {
		url = os.Getenv("BUSINESS_ORDER_API_URL")
	}
	if authorization == "" {
		authorization = os.Getenv("BUSINESS_ORDER_AUTHORIZATION")
	}
	if url == "" {
		return nil, errors.New("BUSINESS_ORDER_API_URL is required")
	}
	if authorization == "" {
		return nil, errors.New("BUSINESS_ORDER_AUTHORIZATION is required")
	}
	return &BusinessOrderClient{client: resty.New(), url: url, authorization: authorization}, nil
}

func (c *BusinessOrderClient) Close() error {
	return c.client.Close()
}

func (c *BusinessOrderClient) FetchByProID(ctx context.Context, proID string) ([]model.BusinessOrderValue, error) {
	var order model.BusinessOrder
	resp, err := c.client.R().
		SetContext(ctx).
		SetHeaders(map[string]string{
			"Content-Type":  "application/x-www-form-urlencoded",
			"Authorization": c.authorization,
		}).
		SetFormData(map[string]string{
			"proId":      proID,
			"systemType": "yunguan",
			"pageSize":   "10",
			"pageNo":     "1",
		}).
		Post(c.url)
	if err != nil {
		return nil, err
	}
	if resp.StatusCode() < http.StatusOK || resp.StatusCode() >= http.StatusMultipleChoices {
		return nil, fmt.Errorf("business order api status: %d", resp.StatusCode())
	}
	if err := json.Unmarshal(resp.Bytes(), &order); err != nil {
		return nil, err
	}
	return order.Data.Values, nil
}
