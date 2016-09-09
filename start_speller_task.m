%% SSVEP Visual Stimulator / Speller Application
function start_speller_task
 
%SSVEP Speller Options
options = [];

% Set Speller Modes
options.debugMode = false;
options.spellerMode = 'copyspell';
options.offlineMode = true;
options.wordPredictionMode = false;
options.twitterMode = false;
options.TTS_Mode = false; 
options.src_parallel_mode=false;

% Set Speller Parameters
options.CUE_DUR = 2;
options.FB_DUR = 1;
options.stimDuration = 4;
options.numTarg = 40;

fullmat = '1234567890ABCDEFGHIJKLMNOPQRSTUVWXYZ';
copySpellParadigm = fullmat(randperm(length(fullmat)));
options.copySeq = [copySpellParadigm(1:8)];
% options.copySeq = '12341234';
options.copySeq = options.copySeq(randperm(length(options.copySeq)));
options.sourceType = 'LSL';
options.classifierType = 'CCA';
options.channels = 23:32;
options.showStart = true;

% Set Subject Parameters (only for online mode)
options.trainFileName = [];
options.sub_info.sub_id='001';
options.sub_info.session_id='001';
options.sub_info.run_id='001';
options.data_dir = ['C:\Users\SSVEP\Desktop\SSVEP EXPERIMENT\Data\'];

 % initialze speller
BCI = speller(options);

% run speller app
start(BCI);


end