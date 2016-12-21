%% SSVEP Visual Stimulator / Speller Application
function start_fmri_speller
 
%SSVEP Speller Options
options = [];

% Set Speller Modes
options.debugMode = true;
options.spellerMode = 'copypell';
options.offlineMode = true;
options.wordPredictionMode = false;
options.twitterMode = false;
options.TTS_Mode = false; 
options.src_parallel_mode=false;

% Set Speller Parameters
options.CUE_DUR = 1;
options.FB_DUR = 1;
options.stimDuration = 2;
options.numTarg = 3;
options.copySeq = 'ABC';
options.sourceType = 'LSL';
options.classifierType = 'CCA';
options.channels = 1:16;
options.showStart = true;
options.vBlockSize = [];
options.hBlockSize = [];

% Set Subject Parameters
options.trainFileName = [];
options.SUB_DATA.sub_id='001';
options.SUB_DATA.session_id='001';
options.SUB_DATA.run_id='001';
options.data_dir = ['D:\Columbia Work\Data'];

 % initialze speller
BCI = fmri_speller(options);

% run speller app
start(BCI);


end