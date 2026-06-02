# EEG 微状态分析流程

[English](README.md) | **简体中文**

基于 **MATLAB + EEGLAB** 的**通用**静息态脑电（EEG）**预处理**与
**微状态（microstate）分析**可复现流程。不限定具体人群或范式——可用于
患者 vs 对照、被试内不同条件（如闭眼/睁眼、前/后、用药开/关），或单组分析。

本仓库在原始 EEGLAB 预处理片段的基础上，整理为参数化、可批处理的工程，
并补全了**微状态聚类、回拟合、参数提取与组间统计**等环节。

---

## 1. 项目能做什么

```
原始 .mff ──► 预处理 ──► 组水平微状态聚类 ──► 回拟合 ──► 参数提取 ──► 组间统计/绘图
```

完整流程分五步：

| 步骤 | 脚本 | 说明 |
|------|------|------|
| 1. 预处理 | `code/preprocessing/batch_preprocess.m` | 导入、滤波、ASR 清理、平均参考、ICA + ICLabel 去伪迹、球面插补 |
| 2. 微状态聚类 | `code/microstate/microstate_segment.m` | 在所有被试 GFP 峰上做修正 k-means，得到共享原型图 A/B/C/D |
| 3. 回拟合 | `code/microstate/microstate_backfit.m` | 将原型回拟合到每个被试连续数据，平滑并计算参数 |
| 4. 参数导出 | `code/microstate/export_microstate_stats.m` | 整理为分析友好的 CSV（含转移概率） |
| 5. 组间统计 | `code/stats/group_statistics.m` | 条件间或组间 t 检验、FDR 校正、柱状图 |

微状态参数包括：**平均持续时间 (Duration)**、**出现频率 (Occurrence)**、
**时间覆盖率 (Coverage)**、**全局解释方差 (GEV)** 和 **转移概率 (Transition Probabilities)**。

---

## 2. 环境依赖

- **MATLAB** R2018b 或更高。
  *无需 Statistics and Machine Learning Toolbox* —— t 检验 p 值用不完全 beta 函数
  （`betainc`）自行计算。
- **EEGLAB** 2021 或更高 —— <https://sccn.ucsd.edu/eeglab/>
  - 用到的自带插件：**clean_rawdata**（ASR）、**ICLabel**、**MFFMatlabIO**（读取 EGI `.mff`）。
    若缺失，在 EEGLAB 菜单 *File → Manage EEGLAB extensions* 中安装。
- **Microstate EEGlab toolbox**（Poulsen et al., 2018）—— 微状态步骤必需
  - <https://github.com/atpoulsen/Microstate-EEGlab-toolbox>
  - 可放入 `eeglab/plugins/`（自动加载），或在配置中指定路径（`cfg.paths.microstate_toolbox`）。

> 参考数据为 256 导联 EGI（GSN-HydroCel）`.mff` 文件；其他格式（`.set`/`.edf`/`.bdf`）
> 可通过 `cfg.import.format` 支持。

---

## 3. 目录结构

```
EEG-Microstate/
├── README.md                    # 英文说明（默认）
├── README.zh-CN.md              # 本文件（中文）
├── config/
│   ├── pipeline_config.m        # ★ 所有参数集中在此
│   ├── subjects_template.csv    # 被试清单模板
│   └── subjects.csv             # （你创建）实际被试清单
├── code/
│   ├── run_all.m                # ★ 主入口
│   ├── preprocessing/
│   │   ├── preprocess_subject.m # 单被试预处理
│   │   └── batch_preprocess.m   # 批量预处理
│   ├── microstate/
│   │   ├── microstate_segment.m       # 组聚类
│   │   ├── microstate_backfit.m       # 回拟合 + 统计
│   │   └── export_microstate_stats.m  # 导出 CSV
│   ├── stats/
│   │   └── group_statistics.m   # 组间统计 + 绘图
│   └── utils/
│       ├── init_eeglab.m        # 启动 EEGLAB（无界面）
│       ├── load_subjects.m      # 读取清单
│       └── log_msg.m            # 日志
├── docs/
│   ├── pipeline.md              # 流程详解
│   ├── methods.md               # 论文方法学描述
│   └── references.md            # 参考文献
├── data/
│   ├── raw/                     # 原始 .mff（不纳入版本控制）
│   └── derivatives/             # 预处理与标注后的 .set（不纳入版本控制）
└── results/                     # 统计表与图（不纳入版本控制）
```

> `data/` 与 `results/` 中的数据文件默认被 `.gitignore` 排除，**不会**被提交。

---

## 4. 快速开始

```matlab
% 1) 编辑配置：填入 EEGLAB 路径（及微状态工具箱路径）
edit config/pipeline_config.m      % 设置 cfg.paths.eeglab

% 2) 准备被试清单：复制模板并填入你的被试
copyfile('config/subjects_template.csv', 'config/subjects.csv');
edit config/subjects.csv

% 3) 把原始 .mff 放进 data/raw/（或在 subjects.csv 中写绝对路径）

% 4) 运行完整流程
cd code
run_all
```

也可在 `code/run_all.m` 中逐节（Ctrl+Enter）执行，便于检视每一步结果。

### 被试清单格式（`config/subjects.csv`）

| 列 | 含义 | 示例 |
|----|------|------|
| `subject_id` | 被试编号 | `sub-01` |
| `group` | 组别 | `PD` / `HC` |
| `condition` | 条件（配对设计的两个水平）| `cond1` / `cond2` |
| `raw_file` | 相对 `data/raw/` 的文件名，或绝对路径 | `sub-01_cond1.mff` |

被试内（配对）比较时，同一 `subject_id` 每个 `condition` 各写一行。
若做组间比较，设 `cfg.stats.factor = 'group'`、`cfg.stats.design = 'independent'`。

---

## 5. 关键配置

所有参数集中在 [`config/pipeline_config.m`](config/pipeline_config.m)，常改的字段：

| 字段 | 用途 | 默认值 |
|------|------|--------|
| `cfg.paths.eeglab` | EEGLAB 安装目录（**必填**）| `''` |
| `cfg.paths.microstate_toolbox` | 微状态工具箱路径（若非插件安装）| `''` |
| `cfg.import.format` | 原始格式：`mff` / `set` / `edf` / `bdf` | `mff` |
| `cfg.filter.bandpass_lo/hi` | 带通截止（Hz）| `1` / `40` |
| `cfg.filter.notch_lo/hi` | 陷波频带（Hz）| `48` / `52` |
| `cfg.resample.srate` | 目标采样率（Hz）| `500` |
| `cfg.ica.pca` | ICA 的 PCA 维数，`[]` = 自动（数据秩）| `[]` |
| `cfg.iclabel.flag_thresholds` | ICLabel 剔除概率阈值 | 伪迹类 `0.7` |
| `cfg.micro.Nmicro_final` | 微状态数（`[]` = 交互选择）| `4` |
| `cfg.stats.factor` / `cfg.stats.design` | 对比因子（`condition`/`group`）与设计（`paired`/`independent`）| `condition` / `paired` |
| `cfg.stats.correction` | 多重比较校正（`fdr`/`bonferroni`/`none`）| `fdr` |

---

## 6. 输出（`results/`）

| 文件 | 内容 |
|------|------|
| `group_prototypes.set` / `.mat` | 组水平微状态原型图（共享 A/B/C/D…）|
| `fig_microstate_prototypes.png` | 原型地形图 |
| `microstate_measures.csv` | 每被试每微状态的 Duration/Occurrence/Coverage/GEV（宽表）|
| `microstate_transitions.csv` | 转移概率矩阵（长表）|
| `microstate_group_stats.csv` | 组间/条件间 t 检验、FDR 校正后 p 值、效应量 |
| `fig_<measure>_by_<factor>.png` | 各参数的分组柱状图（含显著性星标）|

`microstate_measures.csv` 与 `microstate_transitions.csv` 可直接导入
R / SPSS / Python 做进一步建模（如线性混合效应模型）。

---

## 7. 与原始 pipeline 的关系

本工程**忠实保留**了原始预处理参数（带通 1–40 Hz、陷波 48–52 Hz、重采样 500 Hz、
`clean_rawdata`/ASR 的全部阈值、平均参考、`runica` extended、ICLabel 阈值 0.7、
球面插补），同时做了两点工程化改进，均可在 `config/pipeline_config.m` 中开关：

1. **ICA 的 PCA 维数**默认改为按**数据有效秩**自动确定（`cfg.ica.pca = []`），
   避免在 `clean_rawdata` 移除坏导后固定 `pca=253` 造成的秩不匹配；
   如需复刻原值，将其设为 `253`。
2. **插补后再次平均参考**（`cfg.reref.after_interp = true`）：
   微状态分析对参考敏感，插补会引入新通道，故重做平均参考（推荐）。

详见 [`docs/pipeline.md`](docs/pipeline.md) 的逐步说明与依据。

---

## 8. 注意事项

- 由于原文档仅含预处理片段，**微状态部分的方法选择**（修正 k-means、K=4、
  GFP 峰聚类、忽略极性、30 ms 平滑等）采用了领域内**标准默认值**，全部在配置中可调。
- **微状态数 K** 默认固定为 4（经典 A/B/C/D）。若想数据驱动地选择，
  将 `cfg.micro.Nmicro_final = []`，并交互检视 CV 曲线后再固定。
- 单位：`pop_micro_stats` 返回的 Duration/Occurrence 单位随工具箱版本略有差异，
  导出表保留原始数值，请按所用版本核对（详见 [`docs/methods.md`](docs/methods.md)）。
- 本流程默认 **静息态** 数据；任务态/分段数据需调整 `cfg.micro.select.datatype`。

---

## 9. 参考文献

完整列表见 [`docs/references.md`](docs/references.md)。核心工具与方法：
EEGLAB (Delorme & Makeig, 2004)、ICLabel (Pion-Tonachini et al., 2019)、
ASR/clean_rawdata (Mullen et al., 2015)、微状态方法 (Pascual-Marqui et al., 1995;
Michel & Koenig, 2018)、Microstate EEGlab toolbox (Poulsen et al., 2018)。

---

## 许可

[MIT](LICENSE)。研究数据请遵循相应伦理审批与数据使用协议，勿提交至本仓库。
