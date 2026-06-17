# Reproduce the EnvEval 14-repo extension

Lazy, copy-paste guide. Target: a fresh Linux box (Ubuntu 22.04+) with
sudo, internet, and ideally an NVIDIA GPU.

If anything below fails, fall back to the longer guide at
`benchmark/14repo/README.md`.

---

## 0. One-time machine prep

```bash
# System packages
sudo apt update
sudo apt install -y docker.io screen python3 python3-venv python3-pip git curl

# Add yourself to docker group, then log out / back in
sudo usermod -aG docker "$USER"
newgrp docker   # or: log out, log back in
docker ps       # should not require sudo
```

## 1. Clone repos

```bash
mkdir -p ~/repos
cd ~/repos

# EnvEval (Sam fork)
git clone https://github.com/SamLovesHoneyWater/EnvEval.git
# EnvGym-14Add — provides the 14-repo dockerfiles
git clone https://github.com/EaminC/EnvGym-14Add.git
```

If you already have EnvEval cloned, just pull:

```bash
cd ~/repos/EnvEval && git pull origin main
```

## 2. Python env + deps

```bash
cd ~/repos/EnvEval/benchmark
python3 -m venv .venv
source .venv/bin/activate
pip3 install -r requirements.txt
```

Every later step assumes this venv is active. If you open a new shell:

```bash
cd ~/repos/EnvEval/benchmark && source .venv/bin/activate
```

## 3. Bootstrap the 14-repo extension

```bash
cd ~/repos/EnvEval/benchmark/14repo

# 3a. Normalize the 6 bare-name rubrics (idempotent)
python3 fix_14_rubrics.py

# 3b. Reorganize EnvGym-14Add dockerfiles into ./ENVGYM-14repo/
python3 reorganize_14_dockerfiles.py

# 3c. Clone the 14 source repos to ../data/<canonical_name>/
chmod +x down_14.sh
./down_14.sh
```

Expected disk after this step: ~5–10 GB in `benchmark/data/`.

## 4. Sanity checks (no Docker yet)

```bash
cd ~/repos/EnvEval/benchmark/14repo

# All 14 rubrics conform to schema
python3 validate_14_rubrics.py
# expect: "Validated 14 rubrics, 14 passed, 0 failed."

# 42 dockerfiles discoverable, 3 distinct model labels, no path collisions
python3 test_end_to_end_discovery.py
# expect: "All discovery checks passed."

# Full pre-flight without launching builds
python3 run_14_repos.py --dry-run
# expect: "[OK]  all 14 rubrics validated"
```

If any of these fail, **stop and fix before going further.** They take a few
seconds each and catch the bulk of misconfiguration issues.

## 5. Real run

This step does docker builds for 42 dockerfiles. Plan for several hours.
Run inside a `screen` so an ssh disconnect doesn't kill it.

```bash
cd ~/repos/EnvEval/benchmark/14repo

screen -S parent
# inside the screen, with venv active:
python3 run_14_repos.py --batch-size 4
```

Detach with `Ctrl-a d`. Re-attach later with `screen -r parent`.

You can watch a child screen with e.g. `screen -ls` then
`screen -r eval14_<timestamp>_<rand>_<repo>`. Do NOT kill these with
`Ctrl-d`; use `Ctrl-a d` to detach.

## 6. Inspect results

After the run finishes, results are under:

```
benchmark/14repo/reports-by-model/ours-{anthropic,tensorblock}/<model>/<repo>/evaluation_report.json
benchmark/14repo/reports-by-repo/<repo>/<repo>_summary.json
benchmark/14repo/reports-by-repo/<repo>/<repo>_comparison.md
```

Quick eyeball:

```bash
cd ~/repos/EnvEval/benchmark/14repo

# How many reports got written?
find reports-by-model -name "evaluation_report.json" | wc -l   # expect 42

# Which repos finished?
ls reports-by-repo

# Best performer per repo
for d in reports-by-repo/*/; do
  python3 -c "import json,sys;j=json.load(open('${d}/$(basename $d)_summary.json'));print('${d%/}'.split('/')[-1], j['best_performer']['model'], j['best_performer']['total_score'], '/', j['best_performer']['max_score'])"
done
```

---

## Common subset / debugging recipes

```bash
# Run only one repo (smoke test)
python3 run_14_repos.py --repos lllyasviel_Fooocus --no-screen

# Run two repos, no screen, no docker cleanup between batches
python3 run_14_repos.py --repos MouseLand_Kilosort,nesaorg_bootstrap \
                       --no-screen --skip-docker-cleanup

# Skip repos already evaluated (re-run after a partial failure).
# batch_evaluate.py supports --skip-existing; pass it through manually:
python3 ../batch_evaluate.py \
   --skip-warnings --verbose --skip-existing \
   --rubric-dir ../rubrics/manual \
   --baseline-dir ENVGYM-14repo \
   --reports-by-model-dir reports-by-model \
   --reports-by-repo-dir  reports-by-repo \
   --repo lllyasviel_Fooocus

# Free disk between long runs
docker system prune -a --volumes -f
```

---

## What goes wrong and how to fix it

| Symptom | Likely cause | Fix |
|---|---|---|
| `ERROR: rubric dir not found` | wrong cwd or bad `--rubric-dir` | scripts are cwd-independent; check spelling |
| `[FAIL] baseline dir not found` | step 3b skipped | `python3 reorganize_14_dockerfiles.py` |
| `[WARN] <repo>: source not at .../data/<repo>` | step 3c skipped | `./down_14.sh` |
| `Validated 14 rubrics, ... failed` after step 3a | rename collision (both bare and renamed file present) | look at the `[WARN]` from `fix_14_rubrics.py`, manually delete the unwanted one |
| All builds fail with permission denied on docker | not in `docker` group | `sudo usermod -aG docker $USER && newgrp docker` |
| `screen: command not found` | step 0 skipped on a minimal box | `sudo apt install -y screen`, or use `--no-screen` |
| Out of disk during run | docker images/volumes piling up | run with default `--skip-docker-cleanup=False` (the default), or `docker system prune -a --volumes -f` between runs |
| Build hangs forever | one of the heavy GPU repos (Fooocus, CellViT, tao_tutorials) on a CPU box | timeouts in `DockerfileEvaluator.py` will eventually kill it; consider running those repos separately on a GPU box |

---

## What this run produces vs. the original 51-repo run

|  | 51-repo run | 14-repo run |
|---|---|---|
| Entry script | `benchmark/run_all_repos.py` | `benchmark/14repo/run_14_repos.py` |
| Rubric source | `rubrics/manual/*.json` (all) | hard-coded list of 14 |
| Dockerfile dir | `benchmark/ENVGYM-baseline/` | `benchmark/14repo/ENVGYM-14repo/` |
| Methods | 11 (4 baselines + 7 EnvGym) | 3 (EnvGym only) |
| Reports | `benchmark/reports-by-{model,repo}/` | `benchmark/14repo/reports-by-{model,repo}/` |

The two runs are independent — running one does not touch the other's
outputs.
