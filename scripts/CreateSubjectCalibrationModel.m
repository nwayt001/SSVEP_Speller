% Load in Calibration Data and create EEG models


% get .dat file
[dat_file,dat_dir] = uigetfile('*.dat','Select subject"s .dat file','multiselect','off');

% get csv_meta file
[csv_file,csv_dir] = uigetfile('*.csv','Select subject"s meta file','multiselect','off');

% load in the trial labels (.csv file)
[~,~,raw] = xlsread([csv_dir csv_file],'calibration');
for i=1:size(raw,1)-1
    labels(i,:) = raw{i+1,2};
end

% load in the EEG data
[signal, state, parm] = load_bcidat([dat_dir dat_file], '-calibrated');
Fs = parm.SamplingRate.NumericValue;
signal(:,1:end-1) = EEGfilter(signal(:,1:end-1),Fs,2);
idealTrialLen = Fs*6;
trial_idx = find(signal(1:end-1,end)==1 & signal(2:end,end)==0);
trial_idx = trial_idx(1:120);

% Create average template signals
epoched_data=[];
for i=1:length(trial_idx)
    epoched_data(:,:,i) = signal(trial_idx(i)+1:trial_idx(i)+idealTrialLen,1:end-1);
end

% Average Data
fullmatrix='QWERTYUIOPASDFGHJKL?ZXCVBNM,.!$:;() @#&<';
class_labels=[];
label_idx=[];
for j=1:size(labels,1)
    for i=1:length(fullmatrix)
        class_labels(j,i) = findstr(fullmatrix(i),labels(j,:));
    end
    label_idx = [label_idx class_labels(j,:)];
end

for c = 1:length(fullmatrix)
    sub_model(:,:,c) = mean(epoched_data(:,:,label_idx==label_idx(c)),3);
end

trainTemplates = sub_model;  
% save models to be used as base models for SSVEP transfer
save(['data\ClassifierModels\BaseModels'],'trainTemplates');

% % look at some signals
% figure;
% hold off
% plot(trainTemplates(:,2,4),'b');
% hold on;
% plot(trainTemplates_nofilter(:,2,4),'r');
% tmp = Models(:,2,4,3);
% hold on;
% plot(tmp,'g')