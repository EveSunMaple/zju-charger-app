# ZJU Charger Backend

FastAPI data gateway for the ZJU charger app.

Responsibilities:

- periodic full upstream scan
- on-demand station refresh
- latest port-level snapshot
- anonymous device subscriptions and free-port push notifications

## Local

```bash
cd backend
python3 -m venv .venv
.venv/bin/pip install -r requirements-dev.txt
cp .env.example .env
.venv/bin/uvicorn app.main:app --host 0.0.0.0 --port 8000
```

```bash
curl http://127.0.0.1:8000/healthz
curl http://127.0.0.1:8000/v1/meta
curl http://127.0.0.1:8000/v1/snapshot
.venv/bin/pytest -q
```

API details: [`../docs/BACKEND.md`](../docs/BACKEND.md)

Deployment: [`../docs/DEPLOYMENT.md`](../docs/DEPLOYMENT.md)

Push: [`../docs/PUSH.md`](../docs/PUSH.md)
