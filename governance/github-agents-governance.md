# Repository checks

The Apple repository currently has two GitHub workflows: `attribution-guard-agent.yml` and `no-ai-attribution.yml`. Their checked scripts guard commit/content/identity attribution. They remain unchanged in this SDK work. This repository does not have the seven canonical sentinel workflows described by its inherited pre-SDK document; canonical-repository policy lives in the separately pinned authority.

`tools/verify_protected_surface.py --mode product` checks dirty `.github`, governance and CODEOWNERS paths. It does not compare semantic behavior or a historical saved baseline. Intentionally reviewed governance-document corrections are committed normally, then clean protected state is checked. `tools/tests` exercises that guard; `tools/sdk/test_sdk.py` and real disposable framework mutations exercise artifact rejection.

Local execution and actual hosted results are separate evidence. Owner-authorized bypass may satisfy repository integration rules after substantive gates; it does not convert unavailable/failed hosted checks into passing tests. Current source/binary/consumer acceptance belongs in SDK evidence and manifests.
