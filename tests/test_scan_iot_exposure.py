from pathlib import Path
import ast

root = Path(__file__).resolve().parents[1]
source = root / 'agent' / 'agent_loop.py'
text = source.read_text(encoding='utf-8')
ast.parse(text)

assert 'scan_iot_devices' in text, 'scan_iot_devices missing from source'
assert 'if name == "scan_iot_devices":' in text, 'scan_iot_devices dispatcher missing'
assert 'inspect_local_environment immediately as the first and only tool' not in text, 'old IoT blocker still present'

print('SCAN_IOT_SCHEMA_EXPOSED_OK')
print('SCAN_IOT_DISPATCHER_PRESENT_OK')
print('IOT_BLOCKER_ABSENT_OK')
