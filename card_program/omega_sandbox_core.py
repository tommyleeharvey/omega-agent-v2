"""Omega provider-neutral API 3.6 sandbox control plane.
Creator: Thomas Lee Harvey
No PAN, CVV, PIN, track data, or provider secrets are handled.
"""
from dataclasses import dataclass, asdict
from hashlib import sha256
import hmac, json, time

class OmegaCardError(Exception): pass
class ConfigError(OmegaCardError): pass
class PolicyDeclined(OmegaCardError): pass
class DuplicateEvent(OmegaCardError): pass
class SignatureError(OmegaCardError): pass
class StateConflict(OmegaCardError): pass

def canonical_hash(value):
    return sha256(json.dumps(value, sort_keys=True, separators=(",", ":"), default=str).encode()).hexdigest()

def reject_sensitive(value):
    text = json.dumps(value, default=str).lower()
    for marker in ("pan", "cvv", "pin", "track_data", "card_number", "security_code"):
        if marker in text:
            raise OmegaCardError("prohibited credential marker detected")

@dataclass(frozen=True)
class ProcessorConfig:
    processor_name: str
    sandbox_base_url: str
    api_version: str
    auth_scheme: str
    card_create_endpoint: str
    authorization_endpoint_or_mode: str
    provider_idempotency_header: str
    webhook_signature_method: str
    webhook_event_names: tuple
    approved_regions: tuple
    @classmethod
    def from_mapping(cls, raw):
        required = ("processor_name", "sandbox_base_url", "api_version", "auth_scheme", "card_create_endpoint", "authorization_endpoint_or_mode", "provider_idempotency_header", "webhook_signature_method", "webhook_event_names", "approved_regions")
        missing = [k for k in required if not raw.get(k)]
        if missing: raise ConfigError("missing configuration: " + ", ".join(missing))
        if not str(raw["sandbox_base_url"]).startswith("https://"): raise ConfigError("sandbox URL must use HTTPS")
        if "US" not in raw["approved_regions"]: raise ConfigError("US pilot region not approved")
        return cls(str(raw["processor_name"]), str(raw["sandbox_base_url"]).rstrip("/"), str(raw["api_version"]), str(raw["auth_scheme"]), str(raw["card_create_endpoint"]), str(raw["authorization_endpoint_or_mode"]), str(raw["provider_idempotency_header"]), str(raw["webhook_signature_method"]), tuple(raw["webhook_event_names"]), tuple(raw["approved_regions"]))

@dataclass(frozen=True)
class CardRecord:
    provider_card_id: str
    account_ref: str
    product_code: str
    status: str
    created_at: int

@dataclass(frozen=True)
class ProviderEvent:
    provider_event_id: str
    event_type: str
    provider_transaction_id: str
    provider_card_id: str
    account_ref: str
    amount_minor: int
    currency: str
    occurred_at: str
    payload_hash: str

class InMemoryLedger:
    def __init__(self):
        self.cards = {}; self.authorizations = {}; self.postings = []; self.receipts = []; self.accepted_events = set(); self.holds_minor = {}
    def post(self, account_ref, kind, amount_minor, source_id):
        if amount_minor < 0: raise StateConflict("negative posting")
        self.postings.append({"account_ref":account_ref,"kind":kind,"amount_minor":amount_minor,"source_id":source_id})
    def receipt(self, event_type, payload):
        reject_sensitive(payload)
        receipt = {"event_type":event_type,"payload":dict(payload),"payload_sha256":canonical_hash(payload),"created_at":int(time.time()),"proof_status":"ready_for_signed_append"}
        self.receipts.append(receipt); return receipt

class OmegaSandboxControlPlane:
    def __init__(self, config, transport=None, ledger=None, production=False):
        if production and transport is None: raise ConfigError("production transport is not configured")
        self.config=config; self.transport=transport; self.ledger=ledger or InMemoryLedger()
    def _call(self, method, path, body, idempotency_key):
        reject_sensitive(body)
        if self.transport is None: raise ConfigError("no transport injected; no network request made")
        headers={self.config.provider_idempotency_header:idempotency_key,"X-Omega-Api-Version":self.config.api_version}
        return self.transport(method, self.config.sandbox_base_url+path, headers, dict(body))
    def create_virtual_card(self, account_ref, product_code, idempotency_key):
        if not account_ref or not product_code or not idempotency_key: raise PolicyDeclined("required card fields missing")
        result=dict(self._call("POST",self.config.card_create_endpoint,{"account_ref":account_ref,"product_code":product_code},idempotency_key))
        card_id=str(result.get("provider_card_id",""))
        if not card_id: raise StateConflict("provider_card_id missing")
        card=CardRecord(card_id,account_ref,product_code,str(result.get("status","PENDING")),int(time.time()))
        self.ledger.cards[card_id]=card
        return self.ledger.receipt("card.created",asdict(card))
    def authorize(self, provider_card_id, account_ref, amount_minor, currency, available_minor, idempotency_key, policy_version):
        if amount_minor<=0 or amount_minor>available_minor: raise PolicyDeclined("amount violates balance policy")
        card=self.ledger.cards.get(provider_card_id)
        if card and card.status!="ACTIVE": raise PolicyDeclined("card is not active")
        result=dict(self._call("POST",self.config.authorization_endpoint_or_mode,{"provider_card_id":provider_card_id,"account_ref":account_ref,"amount_minor":amount_minor,"currency":currency.upper(),"policy_version":policy_version},idempotency_key))
        tx_id=str(result.get("provider_transaction_id",""))
        if not tx_id: raise StateConflict("provider_transaction_id missing")
        approved=result.get("status")=="approved"
        if approved: self.ledger.holds_minor[account_ref]=self.ledger.holds_minor.get(account_ref,0)+amount_minor
        return self.ledger.receipt("authorization.decided",{"provider_transaction_id":tx_id,"provider_card_id":provider_card_id,"account_ref":account_ref,"amount_minor":amount_minor,"currency":currency.upper(),"decision":result.get("status","UNKNOWN"),"policy_version":policy_version,"idempotency_key":idempotency_key})
    def verify_webhook(self, raw_body, signature, secret):
        if not secret: raise SignatureError("webhook secret unavailable")
        calculated=hmac.new(secret,raw_body,sha256).hexdigest()
        if not hmac.compare_digest(calculated,signature): raise SignatureError("invalid webhook signature")
    def ingest_webhook(self,event):
        if event.provider_event_id in self.ledger.accepted_events: raise DuplicateEvent(event.provider_event_id)
        if event.event_type not in self.config.webhook_event_names: raise StateConflict("event type not approved")
        if event.event_type.endswith("captured"):
            self.ledger.holds_minor[event.account_ref]=max(0,self.ledger.holds_minor.get(event.account_ref,0)-event.amount_minor)
            self.ledger.post(event.account_ref,"CAPTURE",event.amount_minor,event.provider_event_id)
        elif event.event_type.endswith("refund"):
            self.ledger.post(event.account_ref,"REFUND",event.amount_minor,event.provider_event_id)
        self.ledger.accepted_events.add(event.provider_event_id)
        return self.ledger.receipt(event.event_type,asdict(event))
    def reconcile(self, provider_totals):
        local={}
        for p in self.ledger.postings:
            sign=1 if p["kind"]=="REFUND" else -1
            local[p["account_ref"]]=local.get(p["account_ref"],0)+sign*p["amount_minor"]
        diff={a:{"local_minor":local.get(a,0),"provider_minor":v,"difference_minor":local.get(a,0)-v} for a,v in provider_totals.items() if local.get(a,0)!=v}
        return self.ledger.receipt("settlement.reconciled",{"status":"MATCHED" if not diff else "DRIFT","differences":diff})
