% Offline Classification of SSVEP data

% Parameters
USE_CCA=true;
USE_A3CA=false;

% Load in data
datadirEEG = '../data/EEG/';
file_name = 'AA3001/AA3S001R02.dat';
[signal, state, parm] = load_bcidat([datadirEEG file_name], '-calibrated');
Fs = parm.SamplingRate.NumericValue;
% filter?
%signal(:,1:end-1) = EEGfilter(signal(:,1:end-1),Fs,2);

% load in the recorded online results (for comparison)
datadir = '../data/ExperimentData/';
file_name = 'AA3_data.csv';
[~,~,fixed_spell] = xlsread([datadir file_name],'fixed_spell');
[~,~,article] = xlsread([datadir file_name],'article');
gt_labels = [];
pred_labels = [];
% fixed spell section
for i=1:6
    gt_labels = [gt_labels fixed_spell{i+1,4}];
    pred_labels = [pred_labels fixed_spell{i+1,5}];
end
% ny times article section
for i=1:3
    pred_labels = [pred_labels article{i+1,11}];
    gt_labels = [gt_labels article{i+1,11}];
end
% fixed spell section
for i=1:6
    gt_labels = [gt_labels fixed_spell{i+1,4}];
    pred_labels = [pred_labels fixed_spell{i+7,5}];
end

% Create average template signals
trial_idx = find(signal(1:end-1,end)==1 & signal(2:end,end)==0);
idealTrialLen = Fs*6;
epoched_data=[];
for i=1:length(trial_idx)
    epoched_data(:,:,i) = signal(trial_idx(i)+1:trial_idx(i)+idealTrialLen,1:end-1);
end

% Classify with a freakin Kim Kardashian learning!
fullmatrix='QWERTYUIOPASDFGHJKL?ZXCVBNM,.!$:;() @#&<';

% create reference signals
t = 1/Fs:1/Fs:6;

% frequency templates
freqs = [9.6,9.2,8.2,7,8.8,9.8,7.6,9,7.4,8.6,8.4,10,7.2,8,11.2,10.4,11.6,12.4,13,12,11.4,10.8,12.2,10.6,12.8,13.2,11.8,10.2,15.6,14,14.8,14.4,15.8,13.8,15.2,13.4,13.6,15,14.6,15.4];
yRef=[];
for i=1:length(freqs)
    cnt=1;
    for j=1:2
        yRef(i,:,cnt)=sin(2*pi*freqs(i)*j*t);
        cnt=cnt+1;
        yRef(i,:,cnt)=cos(2*pi*freqs(i)*j*t);
        cnt=cnt+1;
    end
end

% classify using CCA
for i=1:size(epoched_data,3)
    y(i,1) = CCA_Classify(epoched_data(:,:,i),yRef);
end
