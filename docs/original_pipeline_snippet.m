% =========================================================================
% 原始 pipeline 片段 (来自项目文档，原样保留作存档)
% Original pipeline snippet (verbatim from the project document, for archive)
% 作者 / author: 张小黑 (zhangxudong)
%
% 本文件仅作记录；可运行、参数化的版本见 code/preprocessing/preprocess_subject.m
% This file is for reference only; the runnable, parameterised version lives in
% code/preprocessing/preprocess_subject.m
% =========================================================================
%
% PD 患者 EEG 预处理 pipeline:
%   import mff data.
%   Filter the data: band pass: 1-40; notch 48-52
%   SR 500
%   Clean rawdata
%   Reref the data
%   ICA - remove components
%   插补 (interpolate):
%       EEG = pop_interp(EEG, full_selected_channels, 'spherical')
%       EEG = eeg_checkset(EEG)

EEG.etc.eeglabvers = 'dev';
EEG = pop_mffimport({'C:\Users\micro\Documents\000脑电课程\术前服药\PD_Med on_Wang ming e_20230427_102415.mff'},'',0,0);
EEG = pop_eegfiltnew(EEG, 'locutoff',1,'hicutoff',40,'plotfreqz',1);
EEG = pop_eegfiltnew(EEG, 'locutoff',48,'hicutoff',52,'revfilt',1,'plotfreqz',1);
EEG = pop_resample( EEG, 500);
EEG = pop_clean_rawdata(EEG, 'FlatlineCriterion',5,'ChannelCriterion',0.8,'LineNoiseCriterion',4,'Highpass','off','BurstCriterion',20,'WindowCriterion',0.25,'BurstRejection','on','Distance','Euclidian','WindowCriterionTolerances',[-Inf 7] );
EEG = pop_reref( EEG, []);
EEG = pop_runica(EEG, 'icatype', 'runica', 'extended',1,'interrupt','on','pca',253);
EEG = pop_iclabel(EEG, 'default');
EEG = pop_icflag(EEG, [NaN NaN;0.7 1;0.7 1;0.7 1;0.7 1;0.7 1;NaN NaN]);
EEG = pop_subcomp( EEG, [], 0);
EEG = eeg_checkset( EEG );
