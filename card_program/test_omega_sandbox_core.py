from hashlib import sha256
import hmac
from omega_sandbox_core import *

def config():
    return ProcessorConfig.from_mapping({"processor_name":"Omega","sandbox_base_url":"https://sandbox.example.invalid/api/v3.6","api_version":"3.6","auth_scheme":"bearer","card_create_endpoint":"/cards","authorization_endpoint_or_mode":"/authorizations","provider_idempotency_header":"Idempotency-Key","webhook_signature_method":"HMAC-SHA256","webhook_event_names":["authorization.captured","refund.created","settlement.posted"],"approved_regions":["US"]})
def transport(method,url,headers,body):
    return {"provider_card_id":"provider_card_001","status":"ACTIVE"} if url.endswith("/cards") else {"provider_transaction_id":"provider_tx_001","status":"approved"}
def main():
    c=OmegaSandboxControlPlane(config(),transport=transport)
    c.create_virtual_card("acct_001","virtual_prepaid_us","create-001")
    d=c.authorize("provider_card_001","acct_001",2500,"USD",10000,"auth-001","pilot-v1")
    assert d["payload"]["decision"]=="approved"
    raw=b'{"event":"authorization.captured"}'; secret=b"sandbox-secret"; sig=hmac.new(secret,raw,sha256).hexdigest(); c.verify_webhook(raw,sig,secret)
    e=ProviderEvent("evt-001","authorization.captured","provider_tx_001","provider_card_001","acct_001",2500,"USD","2026-08-18T00:00:00Z","hash"); c.ingest_webhook(e)
    try: c.ingest_webhook(e); raise AssertionError("duplicate accepted")
    except DuplicateEvent: pass
    assert c.reconcile({"acct_001":-2500})["payload"]["status"]=="MATCHED"
    try: OmegaSandboxControlPlane(config(),production=True); raise AssertionError("production fail-closed broken")
    except ConfigError: pass
    print("OMEGA_SANDBOX_CORE_E2E_OK")
if __name__=="__main__": main()
