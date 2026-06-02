# EEG Microstate Analysis Pipeline

**English** | [简体中文](README.zh-CN.md)

A reproducible, **general-purpose MATLAB / EEGLAB** pipeline for
**preprocessing** and **EEG microstate analysis** of resting-state EEG. It is
not tied to any particular population or paradigm — use it for patients vs.
controls, within-subject conditions (e.g. eyes-closed/eyes-open, pre/post, drug
ON/OFF), or a single group.

The project started from an original EEGLAB preprocessing snippet, which has
been turned into a parameterised, batch-capable codebase; the missing
**microstate clustering, back-fitting, measure extraction, and group statistics**
have been added.

---

## 1. What it does

```
raw .mff ──► preprocess ──► group clustering ──► back-fit ──► measures ──► statistics / figures
```

The full workflow runs in five steps:

| Step | Script | What it does |
|------|--------|--------------|
| 1. Preprocess | `code/preprocessing/batch_preprocess.m` | Import, filter, ASR cleaning, average reference, ICA + ICLabel artifact removal, spherical interpolation |
| 2. Segment | `code/microstate/microstate_segment.m` | Modified *k*-means over all subjects' GFP peaks → shared prototype maps (A/B/C/D) |
| 3. Back-fit | `code/microstate/microstate_backfit.m` | Fit prototypes to each subject's continuous EEG, smooth, compute measures |
| 4. Export | `code/microstate/export_microstate_stats.m` | Flatten to analysis-ready CSVs (incl. transition probabilities) |
| 5. Statistics | `code/stats/group_statistics.m` | Between-condition or between-group *t*-tests, FDR correction, bar charts |

The microstate measures produced are: **mean Duration**, **Occurrence**
(per second), **Coverage** (fraction of time), **GEV** (global explained
variance), and **Transition Probabilities**.

---

## 2. Requirements

- **MATLAB** R2018b or newer.
  *No Statistics and Machine Learning Toolbox is required* — *t*-test p-values are
  computed from the incomplete beta function (`betainc`).
- **EEGLAB** 2021 or newer — <https://sccn.ucsd.edu/eeglab/>
  - Built-in plugins used: **clean_rawdata** (ASR), **ICLabel**, and
    **MFFMatlabIO** (to read EGI `.mff`). If any are missing, install them via the
    EEGLAB menu *File → Manage EEGLAB extensions*.
- **Microstate EEGlab toolbox** (Poulsen et al., 2018) — required for the
  microstate steps.
  - <https://github.com/atpoulsen/Microstate-EEGlab-toolbox>
  - Either drop it into `eeglab/plugins/` (auto-loaded) or set its path in the
    config (`cfg.paths.microstate_toolbox`).

> The reference data are 256-channel EGI (GSN-HydroCel) `.mff` files. Other
> formats (`.set`, `.edf`, `.bdf`) are supported via `cfg.import.format`.

---

## 3. Repository layout

```
EEG-Microstate/
├── README.md                    # this file (English)
├── README.zh-CN.md              # 中文说明
├── config/
│   ├── pipeline_config.m        # ★ ALL parameters live here
│   ├── subjects_template.csv    # subject manifest template
│   └── subjects.csv             # (you create) your manifest
├── code/
│   ├── run_all.m                # ★ master script
│   ├── preprocessing/
│   │   ├── preprocess_subject.m # single-subject preprocessing
│   │   └── batch_preprocess.m   # batch over the manifest
│   ├── microstate/
│   │   ├── microstate_segment.m       # group-level clustering
│   │   ├── microstate_backfit.m       # back-fit + per-subject stats
│   │   └── export_microstate_stats.m  # export CSVs
│   ├── stats/
│   │   └── group_statistics.m   # group statistics & figures
│   └── utils/
│       ├── init_eeglab.m        # launch EEGLAB (headless)
│       ├── load_subjects.m      # read the manifest
│       └── log_msg.m            # timestamped logging
├── docs/
│   ├── pipeline.md              # detailed walkthrough
│   ├── methods.md               # publication-ready Methods text
│   └── references.md            # references
├── data/
│   ├── raw/                     # raw .mff (gitignored)
│   └── derivatives/             # preprocessed / labelled .set (gitignored)
└── results/                     # tables and figures (gitignored)
```

> Data files in `data/` and `results/` are excluded by `.gitignore` and are
> **never** committed.

---

## 4. Quick start

```matlab
% 1) Edit the config: set the EEGLAB path (and the microstate toolbox path)
edit config/pipeline_config.m       % set cfg.paths.eeglab

% 2) Prepare the subject manifest: copy the template and fill it in
copyfile('config/subjects_template.csv', 'config/subjects.csv');
edit config/subjects.csv

% 3) Put the raw .mff files in data/raw/  (or use absolute paths in the manifest)

% 4) Run the whole pipeline
cd code
run_all
```

You can also step through `code/run_all.m` section by section (Ctrl+Enter) to
inspect the output of each stage.

### Manifest format (`config/subjects.csv`)

| Column | Meaning | Example |
|--------|---------|---------|
| `subject_id` | Subject identifier | `sub-01` |
| `group` | Group label | `PD` / `HC` |
| `condition` | Condition (the two levels of a paired design) | `cond1` / `cond2` |
| `raw_file` | Filename relative to `data/raw/`, or an absolute path | `sub-01_cond1.mff` |

For a within-subject (paired) comparison, give each `subject_id` one row per
`condition`. For a between-group comparison, set `cfg.stats.factor = 'group'`
and `cfg.stats.design = 'independent'`.

---

## 5. Configuration highlights

Everything is centralised in [`config/pipeline_config.m`](config/pipeline_config.m).
The most commonly edited fields:

| Field | Purpose | Default |
|-------|---------|---------|
| `cfg.paths.eeglab` | EEGLAB install directory (**required**) | `''` |
| `cfg.paths.microstate_toolbox` | Microstate toolbox path (if not a plugin) | `''` |
| `cfg.import.format` | Raw format: `mff` / `set` / `edf` / `bdf` | `mff` |
| `cfg.filter.bandpass_lo/hi` | Band-pass cutoffs (Hz) | `1` / `40` |
| `cfg.filter.notch_lo/hi` | Notch band (Hz) | `48` / `52` |
| `cfg.resample.srate` | Target sampling rate (Hz) | `500` |
| `cfg.ica.pca` | ICA PCA dim — `[]` = auto (data rank) | `[]` |
| `cfg.iclabel.flag_thresholds` | ICLabel rejection probabilities | `0.7` for artifact classes |
| `cfg.micro.Nmicro_final` | Number of microstates (`[]` = pick interactively) | `4` |
| `cfg.stats.factor` / `cfg.stats.design` | Contrast (`condition`/`group`) and design (`paired`/`independent`) | `condition` / `paired` |
| `cfg.stats.correction` | Multiple-comparison correction (`fdr`/`bonferroni`/`none`) | `fdr` |

---

## 6. Outputs (`results/`)

| File | Contents |
|------|----------|
| `group_prototypes.set` / `.mat` | Group-level microstate prototype maps (shared A/B/C/D…) |
| `fig_microstate_prototypes.png` | Prototype topographies |
| `microstate_measures.csv` | Per-subject, per-map Duration / Occurrence / Coverage / GEV (wide) |
| `microstate_transitions.csv` | Transition-probability matrix (long) |
| `microstate_group_stats.csv` | Group/condition *t*-tests, FDR-corrected *p*-values, effect sizes |
| `fig_<measure>_by_<factor>.png` | Grouped bar charts per measure (with significance stars) |

`microstate_measures.csv` and `microstate_transitions.csv` import directly into
R / SPSS / Python for further modelling (e.g. linear mixed-effects models).

---

## 7. Relation to the original pipeline

This project **faithfully preserves** the original preprocessing parameters
(band-pass 1–40 Hz, notch 48–52 Hz, resample 500 Hz, all `clean_rawdata`/ASR
thresholds, average reference, `runica` extended, ICLabel threshold 0.7,
spherical interpolation). It adds two engineering improvements, both
toggleable in `config/pipeline_config.m`:

1. **ICA PCA dimensionality** now defaults to the **effective data rank**
   (`cfg.ica.pca = []`), avoiding the rank mismatch that a fixed `pca = 253`
   can cause after `clean_rawdata` removes bad channels. Set it to `253` to
   reproduce the original value.
2. **Re-reference after interpolation** (`cfg.reref.after_interp = true`):
   microstate analysis is reference-sensitive and interpolation introduces new
   channels, so the average reference is recomputed (recommended).

See [`docs/pipeline.md`](docs/pipeline.md) for the step-by-step rationale.

---

## 8. Notes & assumptions

- Because the source document contained only the preprocessing snippet, the
  **microstate methodology choices** (modified *k*-means, K = 4, GFP-peak
  clustering, polarity-invariant fitting, 30 ms smoothing) use **standard
  defaults** from the field, all adjustable in the config.
- **Number of microstates K** defaults to 4 (the classic A/B/C/D). For a
  data-driven choice, set `cfg.micro.Nmicro_final = []` and inspect the CV curve
  interactively before fixing K.
- **Units:** the Duration/Occurrence values returned by `pop_micro_stats` vary
  slightly between toolbox versions; the exported tables keep the raw values, so
  verify the units against your installed version (see
  [`docs/methods.md`](docs/methods.md)).
- The pipeline assumes **resting-state** data; for task/epoched data, adjust
  `cfg.micro.select.datatype`.

---

## 9. References

See [`docs/references.md`](docs/references.md) for the full list. Core tools and
methods: EEGLAB (Delorme & Makeig, 2004), ICLabel (Pion-Tonachini et al., 2019),
ASR/clean_rawdata (Mullen et al., 2015), microstate methodology
(Pascual-Marqui et al., 1995; Michel & Koenig, 2018), and the Microstate EEGlab
toolbox (Poulsen et al., 2018).

---

## License

[MIT](LICENSE). Please handle research data in accordance with the relevant
ethics approvals and data-use agreements — do not commit it to this repository.
