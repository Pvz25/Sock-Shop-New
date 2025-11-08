package main

import (
	"bytes"
	"encoding/json"
	"fmt"
	"io"
	"log"
	"net/http"
	"os"
	"time"
)

// Payment authorization request from orders service
type PaymentAuthRequest struct {
	Amount   float64     `json:"amount"`
	Address  interface{} `json:"address"`
	Card     interface{} `json:"card"`
	Customer interface{} `json:"customer"`
}

// Payment authorization response to orders service
type PaymentAuthResponse struct {
	Authorised bool   `json:"authorised"`
	Message    string `json:"message"`
}

// Health check response
type HealthResponse struct {
	Service string `json:"service"`
	Status  string `json:"status"`
	Time    string `json:"time"`
}

// Stripe charge request
type StripeChargeRequest struct {
	Amount   int    `json:"amount"`   // cents
	Currency string `json:"currency"`
	Source   string `json:"source"`
}

// Stripe charge response (simplified)
type StripeChargeResponse struct {
	ID     string `json:"id"`
	Paid   bool   `json:"paid"`
	Status string `json:"status"`
}

var httpClient = &http.Client{
	Timeout: 35 * time.Second,
}

func main() {
	// Get configuration
	port := os.Getenv("PORT")
	if port == "" {
		port = "8080"
	}

	gatewayURL := os.Getenv("PAYMENT_GATEWAY_URL")
	if gatewayURL == "" {
		log.Println("⚠️  PAYMENT_GATEWAY_URL not set - running in mock mode")
	} else {
		log.Printf("✅ Payment gateway: %s\n", gatewayURL)
	}

	// Setup routes
	http.HandleFunc("/paymentAuth", handlePaymentAuth)
	http.HandleFunc("/health", handleHealth)

	// Start server
	log.Printf("🚀 Payment service starting on port %s\n", port)
	if err := http.ListenAndServe(":"+port, nil); err != nil {
		log.Fatalf("❌ Server failed: %v", err)
	}
}

func handlePaymentAuth(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodPost {
		http.Error(w, "Method not allowed", http.StatusMethodNotAllowed)
		return
	}

	// Parse request
	var req PaymentAuthRequest
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		log.Printf("❌ Invalid request: %v\n", err)
		respondJSON(w, http.StatusBadRequest, PaymentAuthResponse{
			Authorised: false,
			Message:    "Invalid payment request",
		})
		return
	}

	log.Printf("💳 Payment auth request: amount=%.2f\n", req.Amount)

	// Check if gateway URL is configured
	gatewayURL := os.Getenv("PAYMENT_GATEWAY_URL")
	if gatewayURL == "" {
		// Mock mode - simple amount check
		log.Println("🔄 Mock mode: authorizing locally")
		authorized := req.Amount > 0 && req.Amount <= 100
		respondJSON(w, http.StatusOK, PaymentAuthResponse{
			Authorised: authorized,
			Message:    getMockMessage(authorized),
		})
		return
	}

	// Call external payment gateway
	response := callPaymentGateway(gatewayURL, req.Amount)
	respondJSON(w, http.StatusOK, response)
}

func callPaymentGateway(gatewayURL string, amount float64) PaymentAuthResponse {
	startTime := time.Now()

	// Convert to cents
	amountCents := int(amount * 100)

	// Create Stripe charge request (form-encoded, not JSON)
	// Stripe API uses application/x-www-form-urlencoded
	formData := fmt.Sprintf("amount=%d&currency=usd&source=tok_visa", amountCents)

	// Make HTTP call to gateway
	endpoint := fmt.Sprintf("%s/v1/charges", gatewayURL)
	log.Printf("🌐 Calling payment gateway: %s (amount=%d cents)\n", endpoint, amountCents)

	req, err := http.NewRequest("POST", endpoint, bytes.NewBufferString(formData))
	if err != nil {
		log.Printf("❌ Failed to create HTTP request: %v\n", err)
		return PaymentAuthResponse{
			Authorised: false,
			Message:    "Internal error",
		}
	}

	req.Header.Set("Content-Type", "application/x-www-form-urlencoded")
	req.Header.Set("Authorization", "Bearer sk_test_mock")

	// Execute request
	resp, err := httpClient.Do(req)
	duration := time.Since(startTime)

	if err != nil {
		// Network error (connection refused, timeout, etc.)
		log.Printf("❌ Payment gateway error: %v (%.2fs)\n", err, duration.Seconds())
		return PaymentAuthResponse{
			Authorised: false,
			Message:    fmt.Sprintf("Payment gateway error: %v", err),
		}
	}
	defer resp.Body.Close()

	// Read response
	body, err := io.ReadAll(resp.Body)
	if err != nil {
		log.Printf("❌ Failed to read gateway response: %v\n", err)
		return PaymentAuthResponse{
			Authorised: false,
			Message:    "Payment gateway returned invalid response",
		}
	}

	log.Printf("✅ Gateway response: HTTP %d (%.2fs)\n", resp.StatusCode, duration.Seconds())

	// Handle error status codes
	if resp.StatusCode >= 500 {
		log.Printf("⚠️  Gateway unavailable: HTTP %d\n", resp.StatusCode)
		return PaymentAuthResponse{
			Authorised: false,
			Message:    fmt.Sprintf("Payment gateway unavailable (HTTP %d)", resp.StatusCode),
		}
	}

	if resp.StatusCode == 429 {
		log.Println("⚠️  Gateway rate limited")
		return PaymentAuthResponse{
			Authorised: false,
			Message:    "Payment gateway rate limit exceeded",
		}
	}

	if resp.StatusCode >= 400 {
		log.Printf("⚠️  Gateway error: HTTP %d\n", resp.StatusCode)
		return PaymentAuthResponse{
			Authorised: false,
			Message:    fmt.Sprintf("Payment request failed (HTTP %d)", resp.StatusCode),
		}
	}

	// Parse successful response
	var chargeResp StripeChargeResponse
	if err := json.Unmarshal(body, &chargeResp); err != nil {
		log.Printf("⚠️  Failed to parse gateway response: %v\n", err)
		return PaymentAuthResponse{
			Authorised: false,
			Message:    "Payment gateway returned invalid JSON",
		}
	}

	// Check payment status
	if chargeResp.Paid && chargeResp.Status == "succeeded" {
		log.Printf("✅ Payment authorized: %s\n", chargeResp.ID)
		return PaymentAuthResponse{
			Authorised: true,
			Message:    fmt.Sprintf("Payment authorized (charge: %s)", chargeResp.ID),
		}
	}

	log.Println("❌ Payment declined by gateway")
	return PaymentAuthResponse{
		Authorised: false,
		Message:    "Payment declined by gateway",
	}
}

func handleHealth(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodGet {
		http.Error(w, "Method not allowed", http.StatusMethodNotAllowed)
		return
	}

	health := []HealthResponse{
		{
			Service: "payment",
			Status:  "OK",
			Time:    time.Now().Format(time.RFC3339),
		},
	}

	respondJSON(w, http.StatusOK, health)
}

func respondJSON(w http.ResponseWriter, status int, data interface{}) {
	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(status)
	json.NewEncoder(w).Encode(data)
}

func getMockMessage(authorized bool) string {
	if authorized {
		return "Payment authorized (mock mode)"
	}
	return "Payment declined (mock mode)"
}
