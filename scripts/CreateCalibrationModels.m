% Load in Calibration Data and create EEG models


% get meta data
datadir = '../data/CalibrationData/';
files = dir(datadir);
files = files(3:end);
for i=1:length(files)
    isdir(i)=files(i).isdir;
end
files = files(isdir==0);
num_sub = length(files);

datadirEEG = '../data/EEG/';
filesEEG = dir(datadirEEG);
filesEEG = filesEEG(3:end);
filesEEG = filesEEG(1:end-1);

for sub = 1:num_sub
    % load in the trial labels (.csv file)
    tmp = strsplit(files(sub).name,'_');
    subID = tmp{1};
    
    [~,~,raw] = xlsread([datadir files(sub).name],'calibration');
    for i=1:size(raw,1)-1
        labels(i,:) = raw{i+1,2};
    end
    
    % load in the EEG data
    for i=1:length(filesEEG)
        if(findstr(subID,filesEEG(i).name))
            datadirEEGfile = [datadirEEG filesEEG(i).name];
            break;
        end
    end
    fileEEG = dir(datadirEEGfile);
    [signal, state, parm] = load_bcidat([datadirEEGfile '/' fileEEG(end).name], '-calibrated');
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
    
    Models(:,:,:,sub) = sub_model;
end
trainTemplates = mean(Models,4);
% save models to be used as base models for SSVEP transfer
save(['../data/ClassifierModels/BaseModels'],'trainTemplates');

% look at some signals
figure;
hold off
plot(trainTemplates(:,2,4),'b');
hold on;
plot(trainTemplates_nofilter(:,2,4),'r');
tmp = Models(:,2,4,3);
hold on;
plot(tmp,'g')