classdef StroopTask < handle
% Stoop Task

    properties
        running       
        DEF_STIM_DUR        = 6.0;
        STIM_PRIME_DUR      = 3.0;
        CUE_DUR             = 1.0;
        WHITE               = [255, 255, 255];
        BLACK               = [  0,   0,   0];
        BG_COLOR            = [  0,   0,   0];
        TEXT_FONT           = 'Arial';
        FONT_SIZE           = 28;
        SM_FONT_SIZE        = 18;
        escKey
        enterKey
        letter_keys
        keypress_check_vector
        oldDebugLevel
        screens
        screenNumber
        window
        windowRect
        centX
        centY
        ifi
        vbl
        refreshRateHz
        design
        numTarg = 40;
        fullmatrix
        pixel_size = 32;
        % stroop_params
        stroop_letters = {'E','A','O'};
        stroop_frequencies
        stroop_phases
        stroop_idx
        stroop_fillcolor
        
        % stroop_statistics
        stroop_results
        data_dir
        % PTB Screens
        offScreen
        blankScreen
        startScreen
        endScreen
        stimScreen
        
        % stroop trials
        congruent_type
        congruent_trials
        incongruent_type
        incongruent_trials
        all_stroop_trials
        allwhite_trials
        allwhite_type
        trial_type
        rng_idx
        
        ISI_start
        ISI_stop
        LETTER_stop
        
        % subject info
        sub_info
        SUB_DATA
    end
    
    
    methods 
        %------------------------------------------------------------------
        % Class constructor:
        function self = StroopTask(options)
            rng('shuffle');
            if(nargin==1)
                self.DEF_STIM_DUR = options.stimDuration;
                self.numTarg = options.numTarg;
                self.stroop_letters = options.stroop_letters;
                self.sub_info = options.sub_info;
                self.data_dir = options.data_dir;
            else
                % Get Subject Information
                getSubjectInfo(self); 
            end
            Priority(1); % set to high priority
            initialize(self); % initialize speller display 
            Screen('Preference', 'SkipSyncTests', 1);
        end
        %------------------------------------------------------------------
        
        function getSubjectInfo(self)
            % Open Dialog box to get subject ID and Session Number
            prompt = {'Enter Subject Identifier','Enter Session Number'};
            dlg_title = 'SubInfo';
            num_lines = 1;
            defaultans = {'XXX','1'};
            answer = inputdlg(prompt,dlg_title,num_lines,defaultans);
            self.SUB_DATA.sub_id=answer{1};
            self.SUB_DATA.session_num = answer{2};
        end
        
        %------------------------------------------------------------------
        % Dependencies:
        function start(self)
            %START is the main starting point after initialize
            Screen('Copywindow', self.startScreen, self.window);
            Screen('Flip', self.window);
            user_pause(self); % Pause
            
            %------------------------------------
            % --MAIN STROOP TASK, TRIAL LOOP--
            for i=1:length(self.all_stroop_trials)
                trialStart = tic;
                % generate the stimulus sequence for trial i(2sec)
                %exp_preloadStroopStimulus(self, self.all_stroop_trials(i,:));
                exp_preloadStroopStimulusV2(self, self.all_stroop_trials(i,:),i);
                while toc(trialStart) <= self.CUE_DUR
                    [~, ~, keyCode] = KbCheck([],[],self.keypress_check_vector);
                    if keyCode(self.escKey)
                        break;
                    end
                end
                % display the stimulus to user
                stimulate(self,i); % maximum 4 seconds
            end
            %------------------------------------
            terminate(self); % close out
        end
        
        % function that pauses the paradigm and waits for user input
        function keepGoing = user_pause(self)
            %manual pause
            while 1
                [~, ~, keyCode] = KbCheck([],[],self.keypress_check_vector);
                if keyCode(self.escKey)
                    keepGoing = false;
                    KbReleaseWait;
                    break;
                end
                if keyCode(self.enterKey)
                    keepGoing = true;
                    KbReleaseWait;
                    break;
                end
            end
        end
        
        function stimulate(self,trial)
        % STIMULATE starts the stroop task stimulation and checks for
        % keyboard presses
            self.vbl = Screen('Flip', self.window);
            % Start Gazing (Stimulation) ------------------------------------
            for win_i = 1:1:self.design.LenCode
                % Stimulate
                Screen('CopyWindow', self.stimScreen(win_i), self.window);
                self.vbl = Screen('Flip', self.window, self.vbl + (0.5*self.ifi));
                
                if(win_i ==self.ISI_stop(trial)+1)
                    latency_start = tic;
                end
                
                % check if one of the three keys are pressed
                [~, secs, keyCode, secDiff] = KbCheck([],[],self.keypress_check_vector);
                if (length(unique(keyCode))>1)
                    if keyCode(self.escKey)
                        self.running = false;
                        terminate(self);
                        error('Escape Key Pressed. Program Stopped');
                    end
                    self.stroop_results.press_latency(trial) = secs;
                    self.stroop_results.press_keyCode(trial) = find(keyCode==1,1);
                    self.stroop_results.press_latency_diff(trial) = secDiff;
                    
                    true_latency = toc(latency_start);
                    self.stroop_results.true_latency(trial) = true_latency;
                    
                    break; 
                end
            end % win_i
            Screen('CopyWindow', self.blankScreen, self.window); 
            Screen('Flip', self.window); % return to blank screen after stimulation
        end
        
        
        function initialize(self)
        %INITIALIZE Inits PTB and appropriate stroop stuff
            exp_GenPTBscreens(self);
            
            % initialize stroop results vector
            press_latency = zeros(1,size(self.all_stroop_trials,1));
            press_keyCode = zeros(1,size(self.all_stroop_trials,1));
            press_latency_diff = zeros(1,size(self.all_stroop_trials,1));
            self.stroop_results.press_latency = press_latency;
            self.stroop_results.press_keyCode = press_keyCode;
            self.stroop_results.press_latency_diff = press_latency_diff;
            self.stroop_results.all_stroop_trials = self.all_stroop_trials;
            self.stroop_results.letter_keys = self.letter_keys;
            self.stroop_results.stroop_letters = self.stroop_letters;
            self.stroop_results.stroop_frequencies = self.stroop_frequencies;
            self.stroop_results.stroop_phases = self.stroop_phases;
            self.stroop_results.ISI_start = self.ISI_start;
            self.stroop_results.ISI_stop = self.ISI_stop;
            self.LETTER_stop = self.LETTER_stop;
        end
        
        
        function terminate(self)
        % TERMINATE closes all PTB windows and terminates any objects
            Screen('CloseAll');
            ShowCursor;
            Screen('Preference', 'VisualDebuglevel', self.oldDebugLevel);
            Priority(0);
            
            % save stroop results
            results = self.stroop_results;            
            savefilename = ['data\StroopData\' self.SUB_DATA.sub_id '_' self.SUB_DATA.session_num];
            save(savefilename,'results');
        end
        
        function exp_GenPTBscreens(self)
        % EXP_GENPTBSCREENS generates the main PTB screens used for
        % stimulation and for start and end of experiments. It
        % pre-generates and pre-loads all screens and frames into memory
        % for fast swapping in real-time
            % Initialize PTB toolbox
            HideCursor;
            KbName('UnifyKeyNames');
            self.escKey = KbName('ESCAPE');
            self.enterKey = KbName('Return');
            self.oldDebugLevel = Screen('Preference', 'VisualDebuglevel', 3);
            self.screens = Screen('Screens');
            self.screenNumber = max(self.screens);
            [self.window, self.windowRect] = Screen('OpenWindow', self.screenNumber, self.BG_COLOR, [], [], 2);
            [self.centX, self.centY] = RectCenter(self.windowRect);
            self.ifi = Screen('GetFlipInterval', self.window);
            self.refreshRateHz = round(1/self.ifi);
            display(['Da frequency is : ' num2str(self.refreshRateHz)]);
            % Generate Stimulus design structur
            self.design = exp_GenStimDesign(self, self.refreshRateHz, [self.windowRect(3), self.windowRect(4)], self.DEF_STIM_DUR + self.STIM_PRIME_DUR, self.numTarg);
            self.design.CentWindow = [self.centX, self.centY];
            
            
            % get keyboard positions for stroop letters
            for i=1:length(self.stroop_letters)
                self.letter_keys(i) = KbName(self.stroop_letters(i));
            end
            
            self.keypress_check_vector = zeros(1,256);
            self.keypress_check_vector([self.escKey, self.enterKey, self.letter_keys]) = 1;
            
            % Get the three stroop stimuli/parameters. find the numerical positions
            % of the three stroop letters in the original 40 char speller
            stim_fillColor = cell2mat(self.design.FlickCode');
            for i=1:length(self.stroop_letters)
                for j=1:self.numTarg
                    if(strcmp(self.stroop_letters(i),self.design.Symbol(j)))
                        self.stroop_idx(i) = j;
                        self.stroop_fillcolor(:,:,i) = repmat(stim_fillColor(j,:),3,1)*256;
                    end
                end
            end
            
            self.stroop_frequencies = self.design.StimFreq(self.stroop_idx);
            self.stroop_phases = self.design.StimPhase(self.stroop_idx);
            
            % display stroup parameters
            display('Stroop Letters:')
            display(self.stroop_letters)
            display('Stroop Frequencies')
            display(self.stroop_frequencies)
            display('Stroop Phases')
            display(self.stroop_phases)
            
            % ---------------------------------------------------------------------
            % Create offscreen for start screen
            % ---------------------------------------------------------------------
            self.startScreen = Screen(self.window, 'OpenOffScreenWindow', self.BG_COLOR,[],self.pixel_size);
            
            Screen(self.startScreen, 'TextColor', self.WHITE);
            Screen(self.startScreen, 'TextFont', self.TEXT_FONT);
            Screen(self.startScreen, 'TextSize', self.FONT_SIZE);
            
            startMsg = ['You are about to start the stroop task. In this task, a single flashing letter will appear at the center of the screen' ...
                ' and you are to press the keyboard key that corresponds to the flashing letter. After 1 second, the next trial begins with another letter.' ...
                ' There are approximately 120 trials. \n'...
                ' Press "ENTER" to begin'];  
            
            DrawFormattedText(self.startScreen,WrapString(startMsg),'center','center',[],[],[],[],2);
            
            % pre-generate 240+ screens to hold the stimulus frames
            self.stimScreen = zeros(1,self.design.LenCode);
            for win_i = 1:self.design.LenCode
                self.stimScreen(win_i) = Screen(self.window, 'OpenOffScreenWindow', self.BG_COLOR);
            end
            % generate blank screen
            self.blankScreen = Screen(self.window, 'OpenOffScreenWindow', self.BG_COLOR);
            % Pre-generate all stroop stimulus sequences for each
            % congruent/incongruent pair. 9 total (3x3 matrix)
            
            % create congruent trials and randomize
            self.congruent_trials=[];
            for i=1:3
                self.congruent_type(i,:) = [i i];
                self.congruent_trials = [self.congruent_trials; repmat(self.congruent_type(i,:),16,1)];
            end
            self.congruent_trials = self.congruent_trials(randperm(length(self.congruent_trials)),:);
            
            % create incongruient trials
            self.incongruent_trials=[];
            cnt=1;
            for i=1:3
                for j=1:3
                    if(i~=j)
                        self.incongruent_type(cnt,:) = [i j];
                        self.incongruent_trials = [self.incongruent_trials; repmat(self.incongruent_type(cnt,:),8,1)];
                        cnt = cnt+1;
                    end
                end
            end
            self.incongruent_trials = self.incongruent_trials(randperm(length(self.incongruent_trials)),:);
            
            
            % create no flashing trials
            self.allwhite_trials=[];
            for i=1:3
                self.allwhite_type(i,:) = [i 4];
                self.allwhite_trials = [self.allwhite_trials; repmat(self.allwhite_type(i,:),16,1)];
            end
            self.allwhite_trials = self.allwhite_trials(randperm(length(self.allwhite_trials)),:);
            
            
            self.all_stroop_trials = [self.congruent_trials; self.incongruent_trials; self.allwhite_trials];
            
            % add in labels for trial type (i.e.
            self.trial_type = [ones(length(self.congruent_trials),1)*1; ones(length(self.incongruent_trials),1)*2; ones(length(self.allwhite_trials),1)*3];
            self.rng_idx = randperm(length(self.all_stroop_trials));
            self.all_stroop_trials = self.all_stroop_trials(self.rng_idx,:);
            
            
            % create jitter onsets
            for i=1:length(self.all_stroop_trials)
                self.ISI_start(i) = self.STIM_PRIME_DUR * self.refreshRateHz;                
                self.ISI_stop(i) = (self.STIM_PRIME_DUR * self.refreshRateHz) + 11 + randi(4);  % this code is not robust against refresh rates other than 60Hz!!
                self.LETTER_stop(i) = self.ISI_stop(i) + 15;
                % this will produce ISI durations approx between 200-250ms
            end
            
        end
        
        function exp_preloadStroopStimulusV2(self,trial,trial_number)
            % -------------------------------------------------------------
            % Populate all frames according to the letter and frequency
            % -------------------------------------------------------------
            letter_idx = trial(1);
            freq_idx = trial(2);  
            stim_rect = [self.centX - self.design.LenSide/2,...
                    self.centY - self.design.LenSide/2,...
                    self.centX + self.design.LenSide/2,...
                    self.centY + self.design.LenSide/2];
            bounds = Screen(self.window, 'TextBounds', self.stroop_letters{letter_idx});
            stim_text_loc =[self.centX-bounds(RectRight)/1.5, self.centY-bounds(RectBottom)/1.5];
            
            for win_i = 1:self.design.LenCode
                % always start by drawing black
                Screen('FillRect', self.stimScreen(win_i), self.BLACK, stim_rect);
                Screen('FrameRect',self.stimScreen(win_i), self.BLACK, stim_rect);
                if(win_i <= self.ISI_start(trial_number))
                    if(freq_idx == 4)
                        Screen('FillRect', self.stimScreen(win_i), self.WHITE, stim_rect);
                        Screen('FrameRect',self.stimScreen(win_i), self.WHITE, stim_rect);
                    else
                        Screen('FillRect', self.stimScreen(win_i), self.stroop_fillcolor(:,win_i,freq_idx), stim_rect);
                        Screen('FrameRect',self.stimScreen(win_i), self.stroop_fillcolor(:,win_i,freq_idx), stim_rect);
                    end
                elseif(win_i>self.ISI_start(trial_number) && win_i<=self.ISI_stop(trial_number))
                    Screen('FillRect', self.stimScreen(win_i), self.BLACK, stim_rect);
                    Screen('FrameRect',self.stimScreen(win_i), self.BLACK, stim_rect);
                elseif(win_i>self.ISI_stop(trial_number) && win_i<= self.LETTER_stop(trial_number))
                    Screen('FillRect', self.stimScreen(win_i), self.BLACK, stim_rect);
                    Screen('FrameRect',self.stimScreen(win_i), self.WHITE, stim_rect);
                    Screen(self.stimScreen(win_i), 'TextColor', self.WHITE);
                    Screen(self.stimScreen(win_i), 'TextFont', self.TEXT_FONT);
                    Screen(self.stimScreen(win_i), 'TextSize', self.FONT_SIZE);
                    Screen('DrawText',self.stimScreen(win_i),self.stroop_letters{letter_idx},stim_text_loc(1), stim_text_loc(2),self.WHITE);
                else
                    Screen('FillRect', self.stimScreen(win_i), self.BLACK, stim_rect);
                    Screen('FrameRect',self.stimScreen(win_i), self.BLACK, stim_rect);
                end
            end
        end
        
        
        function exp_preloadStroopStimulus(self, trial)
            % -------------------------------------------------------------
            % Populate all frames according to the letter and frequency
            % -------------------------------------------------------------
            letter_idx = trial(1);
            freq_idx = trial(2);
            stim_rect = [self.centX - self.design.LenSide/2,...
                    self.centY - self.design.LenSide/2,...
                    self.centX + self.design.LenSide/2,...
                    self.centY + self.design.LenSide/2];
            bounds = Screen(self.window, 'TextBounds', self.stroop_letters{letter_idx});
            stim_text_loc =[self.centX-bounds(RectRight)/1.5, self.centY-bounds(RectBottom)/1.5];
            for win_i = 1:self.design.LenCode
                Screen('FillRect', self.stimScreen(win_i), self.BLACK, stim_rect);
                Screen('FrameRect',self.stimScreen(win_i), self.BLACK, stim_rect);
                if(win_i <= round(self.STIM_PRIME_DUR * self.refreshRateHz))
                    if(freq_idx == 4)
                        Screen('FillRect', self.stimScreen(win_i), self.WHITE, stim_rect);
                        Screen('FrameRect',self.stimScreen(win_i), self.WHITE, stim_rect);
                    else
                        Screen('FillRect', self.stimScreen(win_i), self.stroop_fillcolor(:,win_i,freq_idx), stim_rect);
                        Screen('FrameRect',self.stimScreen(win_i), self.stroop_fillcolor(:,win_i,freq_idx), stim_rect);
                    end
                elseif(win_i > round(self.STIM_PRIME_DUR * self.refreshRateHz) && win_i<=round((self.STIM_PRIME_DUR +0.19 + jitter)* self.refreshRateHz))
                    Screen('FillRect', self.stimScreen(win_i), self.BLACK, stim_rect);
                    Screen('FrameRect',self.stimScreen(win_i), self.BLACK, stim_rect);
                elseif(win_i > round((self.STIM_PRIME_DUR +0.19 + jitter)* self.refreshRateHz) && win_i<=round((self.STIM_PRIME_DUR + 0.19 + jitter + 0.25)* self.refreshRateHz))
                    Screen('FillRect', self.stimScreen(win_i), self.BLACK, stim_rect);
                    Screen('FrameRect',self.stimScreen(win_i), self.WHITE, stim_rect);
                    Screen(self.stimScreen(win_i), 'TextColor', self.WHITE);
                    Screen(self.stimScreen(win_i), 'TextFont', self.TEXT_FONT);
                    Screen(self.stimScreen(win_i), 'TextSize', self.FONT_SIZE);
                    Screen('DrawText',self.stimScreen(win_i),self.stroop_letters{letter_idx},stim_text_loc(1), stim_text_loc(2),self.WHITE);
                else
                end
            end
        end
        
        function design = exp_GenStimDesign(self,refresh, resol, stimTime,numTarg)
        %EXP_GENSTIMDESIGN generates a stimulus design structure that
        %contains all of the parameters for the ssvep speller stimulus
        %including the frequency/phase properties of the stimuli
            % stimulus parameters
            DEFAULT_PHASE   = 0.001;
            wid         = resol(1);     % width of screen window
            hei         = resol(2);     % height of screen window
            lenCode     = round(refresh*stimTime);
            numFreq     = numTarg;
            minFreq     = 8.00;
            freqResol   = minFreq/numTarg;
            minPhase    = 0.00;
            phaseResol  = 0.5*pi;
            waveForm    = 'square';
            stimShape   = 'rect';
            numColumn   = min(numTarg,10);
            numRow      = ceil(numTarg/numColumn);
            
            % Set stimulus frequencies and flickering codes for each target
            for column_i = 1:1:numColumn
                for row_i = 1:1:numRow
%                     stimFreq{numColumn*(row_i-1)+column_i} = minFreq + freqResol*(numRow*(column_i-1)+(row_i-1));
                    stimPhase{numColumn*(row_i-1)+column_i} = wrapTo2Pi(minPhase + phaseResol*(numRow*(row_i-1)+(column_i)));
                end % row_i
            end % column_i
            
            % set stim frequencies to: 7Hz - 15.8Hz spaced 0.2Hz apart (45)
            % skipping 7.8, 9.4, 11, 12.6, 14.2 (40 total)            
            %stimFreqTmp = [7:0.2:7.6 8.0:0.2:9.2 9.6:0.2:10.8 11.2:0.2:12.4 12.8:0.2:14.0 14.4:0.2:15.8];
            % randomize (randomize in groups of mid, low and high) ONLY DO THIS ONCE! and save!
            %stimFreqTmp = [stimFreqTmp(randperm(14)) stimFreqTmp(randperm(14)+14) stimFreqTmp(randperm(12)+28)];
            
            % pre-randomized frequencies to use in speller matrix
            stimFreqTmp = [9.6,9.2,8.2,7,8.8,9.8,7.6,9,7.4,8.6,8.4,10,7.2,8,11.2,10.4,11.6,12.4,13,12,11.4,10.8,12.2,10.6,12.8,13.2,11.8,10.2,15.6,14,14.8,14.4,15.8,13.8,15.2,13.4,13.6,15,14.6,15.4];
            
            % convert to cell array
            for i=1:length(stimFreqTmp)
                stimFreq{i} = stimFreqTmp(i);
            end
            
            % Set location for each stimulus
            vBlockSize  = wid/10;
            hBlockSize  = wid/10;
            
            % Set symbols for each stimulus
            tmpSymbol={'Q', 'W', 'E', 'R', 'T', 'Y', 'U', 'I', 'O', 'P',...
                'A', 'S', 'D', 'F', 'G', 'H', 'J', 'K', 'L', '?',...
                'Z', 'X', 'C', 'V', 'B', 'N', 'M', ',', '.', '!',...
                '$',':',';','(',')',' ','@','#','and','<'};  
            
            self.fullmatrix='QWERTYUIOPASDFGHJKL?ZXCVBNM,.!$:;() @#&<';
            
            for i=1:numTarg
                symbol{i} = tmpSymbol{i};
                fbSymbol{i} = tmpSymbol{i};
                if(strcmp(fbSymbol{i},'space') || strcmp(fbSymbol{i},'Tweet'))
                    fbSymbol{i} = ' ';
                end
                if(strcmp(fbSymbol{i},'and'))
                    fbSymbol{i}='&';
                end
            end
            
            % stimulation parameters
            blockSize   = min([vBlockSize, hBlockSize]);
            dist2Targ   = floor(blockSize*0.2);
            lenSide     = blockSize - dist2Targ;
            wTxtFld     = hBlockSize*(numColumn-1) + lenSide;
            hTxtFld     = lenSide/2;
            locTxtFld   = [0, blockSize/2/2 - (blockSize/2*9/2)];
            
            % Set stimulus frequencies and flickering codes for each target
            for targ_i = 1:1:numTarg
                flickCode{targ_i} = exp_GenFlickerCode(self,...
                    lenCode,...
                    stimFreq{targ_i},...
                    round(refresh),...
                    waveForm,...
                    stimPhase{targ_i}+DEFAULT_PHASE);
            end % column_i
            
            % set stimulus location
            centerLoc = [0, 0];
            
            % ---DEBUG INFO---
            % Frequencies and phases
            fprintf('BCI-STIM: Stimulation frequencies and phases are...\n');
            for row_i = 1:1:numRow
                fprintf('BCI-STIM: ');
                for column_i = 1:1:numColumn
                    targ_i = numColumn*(row_i-1)+column_i;
                    fprintf('[%f, %.1fpi], ', stimFreq{targ_i}, stimPhase{targ_i}/pi);
                end % row_i
                fprintf('\n');
            end % column_i
            
            % Symbols
            fprintf('BCI-STIM: Symbols for each target are...\n');
            for row_i = 1:1:numRow
                fprintf('BCI-STIM: ');
                for column_i = 1:1:numColumn
                    targ_i = numColumn*(row_i-1)+column_i;
                    fprintf('"%s", ', symbol{targ_i});
                end % row_i
                fprintf('\n');
            end % column_i
            % ---DEBUG INFO---
            
            design = struct('ModelName' ,'StoopTask',...
                'NumTarg'   ,numTarg,...
                'StimShape' ,stimShape,...
                'LenCode'   ,round(lenCode),...
                'MinFreq'   ,minFreq,...
                'FreqResol' ,freqResol,...
                'StimFreq'  ,{stimFreq},...
                'StimPhase' ,{stimPhase},...
                'FlickCode' ,{flickCode},...
                'LenSide'   ,lenSide,...
                'CenterLoc' ,{centerLoc},...
                'Symbol'    ,{symbol},...
                'fbSymbol'  ,{fbSymbol},...
                'wTxtFld'   ,{wTxtFld},...
                'hTxtFld'   ,{hTxtFld},...
                'LocTxtFld' ,{locTxtFld},...
                'NumRow'    ,{numRow},...
                'NumColumn' ,{numColumn});
        end
        
        function code = exp_GenFlickerCode(~,clen, freq, refresh, varargin)
        % EXP_GENFLICKERCODE generates the flash sequency for each stimuli
        % based on the frequency, waveform type and refreshrate of the
        % monitor.
            if nargin < 2 || isempty(clen)
                error('stats:exp_GenFlickerCode:InputSizeMismatch', 'CLEN, FREQ, REFRESH are required.');
            elseif nargin < 3 || isempty(freq)
                error('stats:exp_GenFlickerCode:InputSizeMismatch', 'FREQ, REFRESH are required.');
            elseif nargin < 4 || isempty(refresh)
                error('stats:exp_GenFlickerCode:InputSizeMismatch', 'REFRESH is required.');
            end % if
            % Select a stimulation signal type
            if nargin < 5 || isempty(varargin{1})
                type = 'sinusoid';
            elseif ischar(varargin{1})
                types = {'sinusoid', 'square'};
                type_i = strmatch(lower(varargin{1}), types);
                if length(type_i) > 1
                    error('stats:exp_GenFlickerCode:BadType', 'Ambiguous value for TYPE: %s', varargin{1});
                elseif isempty(type_i)
                    error('stats:exp_GenFlickerCode:BadType', 'Unknown value for TYPE: %s', varargin{1});
                end % if
                type = types{type_i};
            else
                error('stats:exp_GenFlickerCode:BadType', 'TYPE must be a string.');
            end % if
            
            % Set phase [0 2*pi]
            if nargin < 6 || isempty(varargin{2})
                phase = 0;
            elseif isnumeric(varargin{2})
                phase = wrapTo2Pi(varargin{2});
            end % if
            
            switch type
                
                % Generate flicker code based on square wave
                case 'square'
                    if nargin < 7 || isempty(varargin{3})
                        duty = 50;
                    elseif isnumeric(varargin{3})
                        duty = varargin{2};
                    else
                        error('stats:exp_GenFlickerCode:BadDuty','DUTY must be a number.');
                    end % if
                    
                    index = 0:1:clen-1;
                    tmp = square(2*pi*freq*(index/refresh)+phase, duty);
                    code = (tmp>=0);
                    
                    % Generate flicker code based on sampled sinusoidal wave
                case 'sinusoid'
                    index = 0:1:clen-1;
                    tmp = sin(2*pi*freq*(index/refresh)+phase);
                    %tmp = cos(2*pi*freq*(index/refresh)+phase);
                    code = (tmp+1)/2;
                    
            end % switch model
        end % END exp_GenFlickerCode
        %------------------------------------------------------------------
    end

end