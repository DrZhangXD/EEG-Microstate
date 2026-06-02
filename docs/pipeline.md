# 流程详解 / Pipeline Walkthrough

逐步说明每一环节做了什么、调用的 EEGLAB / 微状态工具箱函数、对应配置项及设计依据。
配置见 [`config/pipeline_config.m`](../config/pipeline_config.m)。

---

## 步骤 0 · 初始化 / Setup

`code/run_all.m` 首先把 `code/` 与 `config/` 加入路径，读取 `pipeline_config()`，
并调用 `init_eeglab(cfg)` 以无界面方式启动 EEGLAB 并校验关键函数（`pop_eegfiltnew`、
`pop_clean_rawdata`、`pop_runica`、`pop_iclabel`、`pop_interp` 及微状态工具箱函数）。

**前置条件**：在配置中设置 `cfg.paths.eeglab`；若微状态工具箱未作为 EEGLAB 插件
安装，则设置 `cfg.paths.microstate_toolbox`。

---

## 步骤 1 · 预处理 / Preprocessing

入口：`batch_preprocess(cfg)` → 逐被试调用 `preprocess_subject(subject, cfg)`。
单个被试失败会被捕获并记录，不影响批处理其余被试。

| 子步骤 | 函数 | 配置项 | 说明 |
|--------|------|--------|------|
| 导入 | `pop_mffimport` | `cfg.import.*` | 读取 256 导联 EGI `.mff`；导入后立即保存完整通道布局 `full_selected_channels` 供插补使用 |
| 带通 | `pop_eegfiltnew` | `cfg.filter.bandpass_lo/hi` | 1–40 Hz 零相位 FIR |
| 陷波 | `pop_eegfiltnew` (`revfilt`) | `cfg.filter.notch_lo/hi` | 48–52 Hz 抑制工频 |
| 重采样 | `pop_resample` | `cfg.resample.srate` | 500 Hz |
| ASR 清理 | `pop_clean_rawdata` | `cfg.clean.*` | 移除坏导与突发伪迹段 |
| 平均参考 | `pop_reref` | `cfg.reref.type` | average reference |
| ICA | `pop_runica` | `cfg.ica.*` | extended Infomax，PCA 降维 |
| 成分分类 | `pop_iclabel` | — | ICLabel |
| 标记+剔除 | `pop_icflag` / `pop_subcomp` | `cfg.iclabel.flag_thresholds` | 概率 > 0.7 的伪迹成分 |
| 插补 | `pop_interp` | `cfg.interp.method` | 球面样条恢复坏导 |
| 二次参考 | `pop_reref` | `cfg.reref.after_interp` | 插补后再平均参考（推荐） |

**输出**：`data/derivatives/<subject>_<condition>_clean.set`，并在 `EEG.etc.preprocessing`
记录处理信息（移除通道数、剔除成分数、所用配置、日期）。

### 关于处理顺序的说明
原始 pipeline 的顺序为「清理 → 平均参考 → ICA → 去成分 → 插补」。本工程保留该顺序，
并在插补后增加一次平均参考（`cfg.reref.after_interp = true`），原因是：插补引入了新
通道、且微状态分析对参考方案敏感，统一为平均参考可保证后续聚类的可比性。如需严格
复刻原始顺序，将该项设为 `false` 即可。

### 关于 PCA 维数
原 pipeline 固定 `pca = 253`（针对 256 导联）。但 `clean_rawdata` 可能移除若干坏导，
导致数据秩低于 253，固定值会引发秩不匹配或不稳定分解。默认 `cfg.ica.pca = []`
表示按数据有效秩自动确定；将其设为 `253` 可还原原值。

---

## 步骤 2 · 组水平微状态聚类 / Segmentation

入口：`microstate_segment(cfg)`（依赖 Microstate EEGlab toolbox）。

1. 载入所有 `*_clean.set` 到 `ALLEEG`。
2. `pop_micro_selectdata`：对每个被试做平均参考 + GFP 归一化，提取 GFP 峰处地形图
   （`MinPeakDist=10` ms，`Npeaks=1000`，`GFPthresh=1`），汇集为一个数据集。
3. `pop_micro_segment`：对汇集峰图做**修正 k-means**（`modkmeans`，忽略极性），
   候选 K = 3–8，重复 50 次，按 GEV 排序，CV 作为模型选择指标。
4. `pop_micro_selectNmicro`：选定最终微状态数（默认 `cfg.micro.Nmicro_final = 4`）。

**输出**：`results/group_prototypes.set`、`results/group_prototypes.mat`、
`results/fig_microstate_prototypes.png`（原型地形图）。

> 若想数据驱动地确定 K：将 `cfg.micro.Nmicro_final = []`，运行后查看 CV 曲线，
> 再把最优 K 写回配置以保证后续可复现。

---

## 步骤 3 · 回拟合与参数提取 / Back-fitting

入口：`microstate_backfit(cfg)`。对每个被试：

1. `pop_micro_import_proto`：导入组原型。
2. `pop_micro_fit`：按空间相关性（忽略极性）逐时间点标记微状态。
3. `pop_micro_smooth`：剔除短于 30 ms 的片段（reject segments）。
4. `pop_micro_stats`：计算 Duration / Occurrence / Coverage / GEV / 转移概率。

**输出**：`data/derivatives/<id>_micro.set`（带标注）、`results/microstate_stats.mat`。

---

## 步骤 4 · 参数导出 / Export

入口：`export_microstate_stats(cfg, stats)`。将每被试统计整理为：
- `results/microstate_measures.csv`（宽表：每行一个被试×条件，列为各参数×各微状态）；
- `results/microstate_transitions.csv`（长表：from → to 的转移概率）。

可直接导入 R / SPSS / Python 做进一步分析。

---

## 步骤 5 · 组间统计 / Statistics

入口：`group_statistics(cfg, T)`。

- 按 `cfg.stats.factor`（`condition` 或 `group`）取两个水平；
- `cfg.stats.design = 'paired'` 时按 `subject_id` 配对做配对 t 检验，
  `'independent'` 时做 Welch t 检验；
- 对 `cfg.stats.measures` 中每个参数 × 每个微状态做检验；
- 用 FDR / Bonferroni 校正（`cfg.stats.correction`）；
- 报告均值、SD、t、df、p、校正后 p、Cohen's d。

**输出**：`results/microstate_group_stats.csv`、`results/fig_<measure>_by_<factor>.png`
（分组柱状图，显著项标注 `*`）。

---

## 常见问题 / Troubleshooting

- **找不到 `pop_micro_*`**：未安装 Microstate EEGlab toolbox，或未在配置中指定其路径。
- **`pop_mffimport` 报错**：缺少 MFFMatlabIO 插件（EEGLAB extensions 中安装）。
- **ICA 很慢**：`runica` 在高密度数据上较慢属正常；可考虑 `'icatype','runica'` 之外的
  加速实现，或先降采样/降维。
- **配对统计样本不匹配**：确认每个 `subject_id` 在两种 `condition` 下都各有一行。
