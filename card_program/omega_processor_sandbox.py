import argparse,json
from pathlib import Path
from omega_sandbox_core import ProcessorConfig,ConfigError

def main():
    p=argparse.ArgumentParser(); p.add_argument("--config",required=True); p.add_argument("--summary",action="store_true"); a=p.parse_args()
    try: c=ProcessorConfig.from_mapping(json.loads(Path(a.config).read_text()))
    except (OSError,json.JSONDecodeError,ConfigError) as e: print(f"CONFIG_INVALID: {e}"); return 2
    print(json.dumps({"processor_name":c.processor_name,"sandbox_base_url":c.sandbox_base_url,"api_version":c.api_version,"auth_scheme":c.auth_scheme,"approved_regions":list(c.approved_regions),"credential_values_loaded":False,"raw_card_data_supported":False},indent=2)); return 0
if __name__=="__main__": raise SystemExit(main())
