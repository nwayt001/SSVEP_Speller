%% SSVEP Visual Stimulator / Speller Application
function start_speller_task

clc
%SSVEP Speller Options
options = [];

% Set Speller Modes
options.debugMode = true;
options.spellerMode = 'copyspell';
options.showFeedback = true;
options.wordPredictionMode = false;
options.twitterMode = false;
options.TTS_Mode = false; 
options.src_parallel_mode=false;

% Set Speller Parameters
options.CUE_DUR = 0;
options.FB_DUR = 1;
options.stimDuration = 4;
options.numTarg = 40;

fullmat = '1234567890ABCDEFGHIJKLMNOPQRSTUVWXYZ';
copySpellParadigm = fullmat(randperm(length(fullmat)));
options.copySeq = [copySpellParadigm(1:8)];
options.copySeq = '123';
options.copySeq = options.copySeq(randperm(length(options.copySeq)));
options.sourceType = 'FT';
options.classifierType = 'CCA';
options.channels = 1:5;
options.showStart = true;

% Set Subject Parameters (only for online mode)
options.trainFileName = [];
options.SUB_DATA.sub_id='001';
options.SUB_DATA.session_num=1;
options.data_dir = ['C:\Users\SSVEP\Desktop\SSVEP EXPERIMENT\Data\'];

 % initialze speller
BCI = speller(options);

% run speller app (Generic)
start(BCI);





end