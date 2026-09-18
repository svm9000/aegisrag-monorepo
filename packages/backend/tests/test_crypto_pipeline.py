import base64
import json
import pytest
from unittest.mock import patch
from fastapi import status

# Helper function to generate an authentic Dev Intercept payload
def generate_dev_sandbox_payload(data_dict: dict) -> dict:
    """Encodes inputs into a raw JSON string to trigger the Dev Intercept sandbox block."""
    json_bytes = json.dumps(data_dict).encode("utf-8")
    return {
        "encrypted_data": base64.b64encode(json_bytes).decode("utf-8"),
        "encrypted_data_key": "bW9jay1rZXk=", 
        "iv": "bW9jay1pdg=="                            
    }

# Helper function to generate an opaque payload that forces KMS/AESGCM execution
def generate_strict_crypto_payload() -> dict:
    """Encodes a string that bypasses the Dev Intercept sandbox, forcing true decryption parsing."""
    return {
        "encrypted_data": base64.b64encode(b"completely_opaque_encrypted_ciphertext_bytes").decode("utf-8"),
        "encrypted_data_key": "bW9jay1rZXk=", 
        "iv": "bW9jay1pdg=="                            
    }

# --- Test Cases ---

def test_secure_ingest_via_dev_sandbox(test_client):
    """Verifies happy-path document indexing via the base64 Dev Intercept mechanism."""
    payload = generate_dev_sandbox_payload({"text": "AegisRAG production trace context.", "metadata": {"source": "ci"}})
    response = test_client.post("/api/v1/ingest", json=payload)
    
    assert response.status_code == status.HTTP_200_OK
    assert response.json()["status"] == "SUCCESSFULLY_INDEXED_SECURE_VAULT"

def test_secure_query_via_dev_sandbox(test_client):
    """Verifies happy-path retrieval pipelines execute cleanly using sandbox mock parameters."""
    payload = generate_dev_sandbox_payload({"query": "What is the security protocol?"})
    response = test_client.post("/api/v1/query", json=payload)
    
    assert response.status_code == status.HTTP_200_OK
    assert "answer" in response.json()
    assert "metrics" in response.json()

def test_malformed_payload_missing_text_throws_400(test_client):
    """Authentically fires a request missing valid text data to ensure FastAPI drops a 400 Bad Request."""
    # Sending an empty string triggers the sandbox block but breaks the router validation gate
    payload = generate_dev_sandbox_payload({"text": "", "metadata": {"source": "malformed_test"}})
    response = test_client.post("/api/v1/ingest", json=payload)

    assert response.status_code == status.HTTP_400_BAD_REQUEST
    assert "Missing explicit text parameter layout." in response.json()["detail"]

def test_invalid_encryption_triggers_401_kms_boundary(test_client):
    """Forces execution down the KMS pipeline and mocks a decryption failure to verify 401 bounds."""
    # We target 'main.kms_client' (the actual instance defined in main.py)
    with patch("main.kms_client.decrypt") as mock_kms_decrypt:
        # Simulate a validation drop or corrupt padding byte exception from boto3
        mock_kms_decrypt.side_effect = Exception("Ciphertext decryption failed")
        
        payload = generate_strict_crypto_payload()
        response = test_client.post("/api/v1/query", json=payload)
        
        assert response.status_code == status.HTTP_401_UNAUTHORIZED
        assert "Cryptographic Bound Failure" in response.json()["detail"]
