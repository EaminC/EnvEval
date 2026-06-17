# EnvEval 14-repo extension

This folder adds 14 new repos to the EnvEval benchmark, evaluated against
3 EnvGym dockerfile-generation methods (anthropic claude-opus-4,
tensorblock gpt-4.1, tensorblock gpt-4.1-mini), for a total of
**3 × 14 = 42 dockerfiles**.

It is fully self-contained: it does not modify the existing 51-repo
pipeline at `../run_all_repos.py`, and it writes its results to
`./reports-by-model/` and `./reports-by-repo/`. It does, however, reuse
`../batch_evaluate.py` and `../DockerfileEvaluator.py` for the actual
evaluation logic — so any change to the rubric format or build pipeline
upstream is automatically picked up.

## TL;DR — running on a fresh Linux box

```bash
# 1. Bootstrap once: get the dockerfiles repo
git clone https://github.com/EaminC/EnvGym-14Add ~/repos/EnvGym-14Add

# 2. Inside this repo, normalize rubrics and reorganize dockerfiles
cd ~/repos/EnvEval/benchmark/14repo
python3 fix_14_rubrics.py             # idempotent; renames + adds categories
python3 reorganize_14_dockerfiles.py  # writes ./ENVGYM-14repo/

# 3. Clone source repos (~tens of GB on disk; some are large)
chmod +x down_14.sh
./down_14.sh

# 4. (Optional) confirm everything is wired up before docker builds start
python3 test_end_to_end_discovery.py
python3 run_14_repos.py --dry-run

# 5. Run for real (long-running; uses screen by default)
screen -S parent
python3 run_14_repos.py --batch-size 4
```

## File layout

```
benchmark/14repo/
├── README.md                      this file
├── fix_14_rubrics.py              renames 6 rubrics, adds missing categories
├── validate_14_rubrics.py         confirms all 14 rubrics conform to schema
├── reorganize_14_dockerfiles.py   builds ENVGYM-14repo/ from EnvGym-14Add
├── test_dockerfile_discovery.py   sanity-checks dockerfile lookup
├── test_end_to_end_discovery.py   simulates run_14_repos pre-build phase
├── down_14.sh                     clones the 14 source repos to ../data/
├── run_14_repos.py                main runner (screen-based or inline)
├── ENVGYM-14repo/                 (generated) reorganized dockerfile tree
└── reports-by-{model,repo}/       (generated) evaluation outputs
```

## Repo set (14)

All 14 repos are referenced by their canonical `<org>_<repo>` name. Six
of these were renamed from a bare-name form during normalization:

| Canonical name | Upstream URL | Was-renamed? |
|---|---|---|
| TIO-IKIM_CellViT-Inference | https://github.com/TIO-IKIM/CellViT-Inference | |
| TIO-IKIM_CellViT-plus-plus | https://github.com/TIO-IKIM/CellViT-plus-plus | yes (was `CellViT-plus-plus`) |
| sideprotocol_plonky2-gpu | https://github.com/sideprotocol/plonky2-gpu | |
| SVRTK_svrtk-docker-gpu | https://github.com/SVRTK/svrtk-docker-gpu | |
| PluralisResearch_node0 | https://github.com/PluralisResearch/node0 | |
| perslev_U-Time | https://github.com/perslev/U-Time | |
| EsmaeilNarimissa_SciDOCX | https://github.com/EsmaeilNarimissa/SciDOCX | |
| nesaorg_bootstrap | https://github.com/nesaorg/bootstrap | |
| NVIDIA-AI-Blueprints_pdf-to-podcast | https://github.com/NVIDIA-AI-Blueprints/pdf-to-podcast | |
| lllyasviel_Fooocus | https://github.com/lllyasviel/Fooocus | yes (was `ai-avatar`) |
| nyu-systems_CLM-GS | https://github.com/nyu-systems/CLM-GS | yes (was `CLM-GS`) |
| MouseLand_Kilosort | https://github.com/MouseLand/Kilosort | yes (was `Kilosort4`) |
| NVIDIA-NeMo_Gym | https://github.com/NVIDIA-NeMo/Gym | yes (was `NeMo_Gym`) |
| NVIDIA_tao_tutorials | https://github.com/NVIDIA/tao_tutorials | yes (was `tao_tutorials`) |

The bare-name rubrics were also missing the mandatory `category` field on
each test, which `batch_evaluate.validate_rubric` enforces. `fix_14_rubrics.py`
assigns a sensible category per test based on its `type`:

| Test type | Category |
|---|---|
| `commands_exist`, `output_contains`, `envvar_set` | `configuration` |
| `files_exist`, `dirs_exist`, `file_contains` | `structure` |
| `run_command` | `functionality` |

## Methods (3)

The dockerfiles in https://github.com/EaminC/EnvGym-14Add come in three
backup directories. `reorganize_14_dockerfiles.py` maps them to:

| EnvGym-14Add backup dir | Reorganized path label | extract_model_info → |
|---|---|---|
| `backup_*_anthropic_claude-opus-4-*_envgym` | `ours-anthropic/claude-opus-4` | `ours-anthropic/claude-opus-4` |
| `backup_*_tensorblock_gpt-4.1_envgym` | `ours-tensorblock/gpt-4.1` | `ours-tensorblock/gpt-4.1` |
| `backup_*_tensorblock_gpt-4.1-mini_envgym` | `ours-tensorblock/gpt-4.1-mini` | `ours-tensorblock/gpt-4.1-mini` |

(There is also an `Untitled/` subdir inside the claude-opus-4 backup that
duplicates the 14 repos; it's a copy-paste artifact and is skipped.)

## Pre-flight checks

`run_14_repos.py --dry-run` validates without launching docker builds:

- All 14 rubrics exist and pass `batch_evaluate.validate_rubric`
- The reorganized `ENVGYM-14repo/` tree exists
- For each repo, exactly 3 dockerfiles are discoverable (one per method)
- Source repos are present at `../data/<canonical_name>/` (warning only;
  pass `--skip-data-check` to silence)

`test_end_to_end_discovery.py` does a stricter walk: 42 dockerfile paths,
3 distinct models, 42 unique report-output paths, no substring collisions.

## Known caveats

1. **Some source repos are large.** `MouseLand_Kilosort` and `lllyasviel_Fooocus`
   are several hundred MB; `NVIDIA_tao_tutorials` is ~1 GB. `down_14.sh`
   uses `git clone --depth 1` to keep clones reasonable, but plan disk
   accordingly. Total source disk usage is roughly **5–10 GB**.

2. **GPU-heavy rubrics may not be exercisable on a CPU box.** Several
   rubrics check for CUDA-related env vars and tools (e.g.,
   `TIO-IKIM_CellViT-Inference`, `SVRTK_svrtk-docker-gpu`,
   `PluralisResearch_node0`). The build still runs; the
   functionality tests just report 0.

3. **No baselines yet for these 14 repos.** Unlike the original 54-repo
   set where each EnvGym method had a paired claude/codex baseline,
   EnvGym-14Add only has 3 EnvGym methods. There are no `claude-3.5-haiku`
   or `codex-gpt41` baselines for the 14-repo set. Any
   "ours-vs-baseline" delta will need a separate baseline run.

4. **`mui_material-ui` is unrelated.** That belongs to the original 54-repo
   set and is not handled here.

5. **Rubric naming** for ambiguous projects (`Kilosort4`, `NeMo_Gym`,
   `ai-avatar`) was decided to match the upstream GitHub repo path
   exactly: `MouseLand_Kilosort` (not `MouseLand_Kilosort4`),
   `NVIDIA-NeMo_Gym` (not `NVIDIA-NeMo_NeMo_Gym`),
   `lllyasviel_Fooocus` (not `lllyasviel_ai-avatar`). This is documented
   in the rename map at the top of `fix_14_rubrics.py` and
   `reorganize_14_dockerfiles.py`.
```

## How this integrates with the rest of EnvEval

- **Rubrics** live alongside the original 51-repo rubrics under
  `../rubrics/manual/`. After `fix_14_rubrics.py` runs, all 14 new
  rubrics are valid. The `--list-repos` mode of `batch_evaluate.py`
  will see all 66 rubrics. The 14-repo runner only iterates a hard-coded
  subset to keep the runs isolated.
- **Dockerfiles** live in this folder under `ENVGYM-14repo/`, NOT in
  `../ENVGYM-baseline/`. We pass an explicit `--baseline-dir` to
  `batch_evaluate.py`.
- **Reports** are written under `./reports-by-model/` and
  `./reports-by-repo/` for the 14-repo set, fully isolated from the
  original 51-repo reports under `../reports-by-{model,repo}/`.
- **Source repos** are shared in `../data/<canonical_name>/`. There's no
  collision because the canonical 14-repo names don't overlap with the
  existing 54-repo names.

## Reproducing on a fresh Linux box

The end-to-end command sequence assumed for the cloud machine is:

```bash
# OS prep: docker, screen, python3.10+, git
sudo apt update
sudo apt install -y docker.io screen python3 python3-venv python3-pip git
sudo usermod -aG docker "$USER"   # then log out / in

# Repos
mkdir -p ~/repos
cd ~/repos
git clone https://github.com/SamLovesHoneyWater/EnvEval.git
git clone https://github.com/EaminC/EnvGym-14Add.git

# Python env
cd ~/repos/EnvEval/benchmark
python3 -m venv .venv
. .venv/bin/activate
pip3 install -r requirements.txt

# Bootstrap 14repo
cd 14repo
python3 fix_14_rubrics.py
python3 reorganize_14_dockerfiles.py
chmod +x down_14.sh
./down_14.sh

# Sanity tests
python3 validate_14_rubrics.py
python3 test_end_to_end_discovery.py
python3 run_14_repos.py --dry-run

# Real run (in a screen session — long-running)
screen -S parent
python3 run_14_repos.py --batch-size 4
# Ctrl-a d to detach; screen -r parent to resume
```

After the run, results live in:

```
benchmark/14repo/reports-by-model/ours-{anthropic,tensorblock}/<model>/<repo>/evaluation_report.json
benchmark/14repo/reports-by-repo/<repo>/<repo>_summary.json
```
