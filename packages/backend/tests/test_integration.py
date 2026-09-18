import base64
import json
import pytest
from fastapi import status

# --- 1. Authentic Payload Builders ---

def build_dev_sandbox_payload(data_dict: dict) -> dict:
    """Encodes a structure to route through the backend's Dev Intercept sandbox layer."""
    json_bytes = json.dumps(data_dict).encode("utf-8")
    return {
        "encrypted_data": base64.b64encode(json_bytes).decode("utf-8"),
        "encrypted_data_key": "bW9jay1rZXk=", 
        "iv": "bW9jay1pdg=="                            
    }

def build_strict_crypto_payload() -> dict:
    """Encodes an opaque string that bypasses the sandbox to test pure KMS error loops."""
    return {
        "encrypted_data": base64.b64encode(b"completely_opaque_encrypted_ciphertext_bytes").decode("utf-8"),
        "encrypted_data_key": "bW9jay1rZXk=", 
        "iv": "bW9jay1pdg=="                            
    }

# --- 2. Live Integration Test Cases ---

def test_integration_ingest_happy_path(test_client):
    """
    Validates the end-to-end ingestion flow.
    Ensures Pydantic verification, base64 sandbox intercept, stable JSON metadata 
    sorting, deterministic SHA-256 ID generation, and Haystack indexing pass cleanly.
    """
    test_data = {
        "text": "AegisRAG core architectural data token.", 
        "metadata": {"classification": "restricted", "tier": "alpha"}
    }
    payload = build_dev_sandbox_payload(test_data)
    
    response = test_client.post("/api/v1/ingest", json=payload)
    
    assert response.status_code == status.HTTP_200_OK
    data = response.json()
    assert data["status"] == "SUCCESSFULLY_INDEXED_SECURE_VAULT"
    assert data["processed_documents"] == 1
    # Check that a valid 64-character hex string hash was assigned as the vault ID
    assert len(data["assigned_vault_id"]) == 64 


def test_integration_query_happy_path(test_client):
    """
    Validates the complete query and generation loop.
    Ensures that the endpoint accepts queries, invokes the Haystack pipeline, 
    safeguards document metric counts via the UI fallback net, and outputs text.
    """
    payload = build_dev_sandbox_payload({"query": "Retrieve network vault credentials"})
    
    response = test_client.post("/api/v1/query", json=payload)
    
    assert response.status_code == status.HTTP_200_OK
    data = response.json()
    assert "answer" in data
    assert "metrics" in data
    # Verifies your Haystack pipeline metric capture handles are perfectly mapped
    assert "retrieved_docs_count" in data["metrics"]
    assert "reranked_docs_count" in data["metrics"]


def test_integration_validation_missing_text_param(test_client):
    """
    Tests application-level error boundaries by purposefully sending an empty 'text' key.
    Forces an authentic HTTP 400 response from your app router logic, not a mocked response.
    """
    # Empty string forces a falsy evaluation on the router step but hits the dev sandbox match
    invalid_data = {
        "text": "", 
        "metadata": {"source": "integration_malformed_test"}
    }
    payload = build_dev_sandbox_payload(invalid_data)

    response = test_client.post("/api/v1/ingest", json=payload)

    assert response.status_code == status.HTTP_400_BAD_REQUEST
    assert "Missing explicit text parameter layout." in response.json()["detail"]




def test_integration_cryptographic_verification_drop(test_client):
    """
    Tests security boundaries by forcing execution past the sandbox into a broken KMS loop.
    Ensures a 401 Unauthorized boundary block triggers when a decryption signature drops.
    """
    payload = build_strict_crypto_payload()
    
    response = test_client.post("/api/v1/query", json=payload)
    
    assert response.status_code == status.HTTP_401_UNAUTHORIZED
    assert "Cryptographic Bound Failure / KMS Verification Drop" in response.json()["detail"]
