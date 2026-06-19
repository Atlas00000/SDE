# ORBVWAP AI pipeline (INF-2)
PYTHON ?= python
AI_DIR := Diagnostics/ai

.PHONY: install replay-all train-all simulate-ai2 validate-schema audit-shadow docker-replay

install:
	$(PYTHON) -m pip install -r requirements-lock.txt

replay-all:
	$(PYTHON) $(AI_DIR)/replay_all.py

train-all:
	$(PYTHON) $(AI_DIR)/train_l1.py
	$(PYTHON) $(AI_DIR)/train_regime.py
	$(PYTHON) $(AI_DIR)/replay_sizing.py
	$(PYTHON) $(AI_DIR)/train_exit.py

simulate-ai2:
	$(PYTHON) $(AI_DIR)/simulate_ai2.py

validate-schema:
	$(PYTHON) $(AI_DIR)/build_dataset.py --validate-parquet Diagnostics/datasets/ORBVWAP_ai_dataset_v1.parquet

audit-shadow:
	@test -n "$(SHADOW_CSV)" || (echo "Set SHADOW_CSV=path/to/ORBVWAP_ai_shadow.csv" && exit 1)
	$(PYTHON) $(AI_DIR)/audit_shadow.py "$(SHADOW_CSV)" --check-ai2

docker-replay:
	docker build -f docker/Dockerfile -t orbvwap-ai .
	docker run --rm -v "$(CURDIR):/orbvwap" -w /orbvwap orbvwap-ai python Diagnostics/ai/replay_all.py
