# 方法学 / Methods

本文给出可直接用于论文方法部分的描述（中英双语），参数与代码一一对应。
所有参数集中在 [`config/pipeline_config.m`](../config/pipeline_config.m)。

A publication-ready Methods description (Chinese + English) mirroring the code.
All parameters live in `config/pipeline_config.m`.

---

## 1. 被试与数据采集 / Participants and recording

> ⚠️ 占位：请根据你的实验填写被试人数、年龄、性别、病程、UPDRS、采集设备与时长。

EEG 数据使用 256 导联 EGI（GSN-HydroCel）系统采集，存储为 `.mff` 格式。
每位 PD 患者在**服药开（Med-ON）**与**停药（Med-OFF）**两种状态下记录静息态
脑电（如闭眼 X 分钟）。

EEG was recorded with a 256-channel EGI (GSN-HydroCel) system and stored in
`.mff` format. Resting-state EEG was acquired from each PD patient in both the
medication **ON** and **OFF** states.

---

## 2. 预处理 / Preprocessing

预处理在 MATLAB 中使用 EEGLAB（Delorme & Makeig, 2004）完成，对应
`code/preprocessing/preprocess_subject.m`：

1. **导入 / Import.** `.mff` 经 MFFMatlabIO 插件导入（`pop_mffimport`）。
2. **滤波 / Filtering.** 使用零相位 FIR 滤波（`pop_eegfiltnew`）：先带通
   1–40 Hz，再 48–52 Hz 陷波抑制工频干扰。
3. **重采样 / Resampling.** 降采样至 500 Hz（`pop_resample`）。
4. **伪迹清理 / Artifact cleaning.** 使用 `clean_rawdata`（Artifact Subspace
   Reconstruction, ASR; Mullen et al., 2015）剔除坏导与高幅突发伪迹段：
   FlatlineCriterion = 5 s，ChannelCriterion = 0.8，LineNoiseCriterion = 4，
   BurstCriterion = 20（SD），WindowCriterion = 0.25，BurstRejection = on。
5. **重参考 / Re-referencing.** 重参考到平均参考（`pop_reref`）。
6. **ICA 去伪迹 / ICA artifact removal.** 扩展 Infomax ICA（`runica`,
   extended = 1）分解，PCA 降维至数据有效秩；随后 ICLabel
   （Pion-Tonachini et al., 2019）自动分类，凡 Muscle/Eye/Heart/Line-noise/
   Channel-noise 类后验概率 > 0.7 的成分予以剔除（`pop_icflag` + `pop_subcomp`）。
7. **插补 / Interpolation.** 对被 ASR 移除的通道做球面样条插补
   （`pop_interp`, spherical; Perrin et al., 1989），恢复至完整导联布局。
8. **最终参考 / Final reference.** 插补后再次平均参考，以保证微状态分析所需的
   参考一致性。

> 与原始 pipeline 的差异（均可在配置中还原）：(i) ICA 的 PCA 维数由原固定 253
> 改为按数据有效秩自动确定，避免移除坏导后秩不匹配；(ii) 增加插补后的二次平均参考。

EEG preprocessing used EEGLAB. Continuous data were imported, band-pass filtered
(1–40 Hz) and notch filtered (48–52 Hz), and downsampled to 500 Hz. Noisy
channels and high-amplitude transients were removed with ASR
(`clean_rawdata`). Data were average-referenced and decomposed with extended
Infomax ICA; components classified by ICLabel as muscle, eye, heart, line-noise
or channel-noise with probability > 0.7 were removed. Removed channels were
recovered by spherical spline interpolation, and the data were re-referenced to
the average reference.

---

## 3. 微状态分析 / Microstate analysis

微状态分析使用 Microstate EEGlab toolbox（Poulsen et al., 2018），对应
`code/microstate/`：

### 3.1 原型估计 / Prototype estimation
在每位被试经平均参考、GFP 归一化的数据上提取**全局场功率（GFP）局部峰**处的
地形图（最小峰间隔 10 ms，每被试取 1000 个峰，剔除 GFP > 1 SD 的离群峰），
汇集所有被试的峰图后，使用**修正 k-means 聚类**（modified k-means;
Pascual-Marqui et al., 1995；忽略地形极性）估计**组水平共享原型图**。
候选微状态数在 3–8 之间，依据**交叉验证准则（CV）**确定，本研究采用经典的
**4 类微状态（A/B/C/D）**（`pop_micro_segment` / `pop_micro_selectNmicro`）。

### 3.2 回拟合与平滑 / Back-fitting and smoothing
将组原型回拟合到每位被试的连续脑电：逐时间点按与各原型的**空间相关性**
（忽略极性）赋予微状态标签（`pop_micro_fit`）。随后做时间平滑，将持续时间
短于 **30 ms** 的片段重新归并（`pop_micro_smooth`, reject segments）。

### 3.3 参数提取 / Microstate measures
对每位被试计算以下微状态参数（`pop_micro_stats`）：
- **平均持续时间 / mean Duration**：每类微状态单次出现的平均时长；
- **出现频率 / Occurrence**：每秒出现次数；
- **覆盖率 / Coverage**：每类占总时间的比例；
- **全局解释方差 / GEV**：每类对总方差的解释比例；
- **转移概率 / Transition probabilities**：各类之间的转移概率矩阵。

> 单位说明：`pop_micro_stats` 返回的 Duration/Occurrence 数值单位随工具箱版本
> 略有差异（Duration 多以 ms 计、Occurrence 以次/秒计）。导出 CSV 保留原始数值，
> 报告前请按所用版本核对。

Microstate analysis followed Poulsen et al. (2018). Topographies at GFP peaks
were pooled across subjects and clustered with a polarity-invariant modified
k-means algorithm to obtain group-level prototype maps; the number of maps
(K = 4, classes A–D) was guided by the cross-validation criterion. Prototypes
were back-fitted to each subject's continuous EEG by spatial correlation,
segments shorter than 30 ms were re-assigned, and per-subject measures (mean
duration, occurrence, coverage, GEV, and transition probabilities) were
computed.

---

## 4. 统计分析 / Statistical analysis

对应 `code/stats/group_statistics.m`。对每个微状态参数（Duration、Occurrence、
Coverage、GEV）逐类比较 **Med-ON vs Med-OFF**：被试内（配对）设计用配对 t 检验，
组间设计用 Welch t 检验。多重比较用 **Benjamini–Hochberg FDR** 校正
（Benjamini & Hochberg, 1995），显著性水平 α = 0.05。同时报告效应量
（配对 Cohen's *d_z* / 独立样本 Cohen's *d*）。

> 实现上 t 分布 p 值由不完全 beta 函数（`betainc`）计算，因此**不依赖**
> Statistics and Machine Learning Toolbox。如样本量较小或参数分布偏态，建议
> 改用置换检验或混合效应模型（可基于导出的 CSV 在 R/Python 中实现）。

Each microstate measure was compared between conditions with paired t-tests
(within-subject design) or Welch's t-tests (between-group design), corrected
for multiple comparisons with the Benjamini–Hochberg FDR procedure
(α = 0.05); effect sizes (Cohen's d) are reported. Two-tailed t p-values are
computed from the incomplete beta function, so no Statistics Toolbox is
required.

---

## 5. 软件与可复现性 / Software and reproducibility

分析流程与全部参数已开源（见本仓库）。预处理信息记录在每个数据集的
`EEG.etc.preprocessing` 字段中以便追溯。引用工具版本时请补全你实际使用的
MATLAB / EEGLAB / 各插件版本号。

See `docs/references.md` for the full reference list.
