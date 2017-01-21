classdef speller < handle
% SPELLER is the main parent class for an SSVEP based speller that uses PTB
% for display and stimulation
    properties
        CUE_DUR             = 0.0;
        FB_DUR              = 1.0;
        DEF_STIM_DUR        = 4.0;
        WHITE               = [255, 255, 255];
        BLACK               = [  0,   0,   0];
        RED                 = [255,   0, 102];
        BLUE                = [102,   0, 255];
        GREEN               = [50,   255, 50];
        BG_COLOR            = [  0,   0,   0];
        YELLOW              = [210,  210,  0];
        TEXT_FONT           = 'Arial';
        FONT_SIZE           = 28;
        SM_FONT_SIZE        = 18;
        COPY_SEQ            = '1234';
        copy_seq            = [];
        TRIAL_CNT           = 1;
        numHarmonics        = 2;
        fb_seq
        fb_seq2
        EXP_END
        escKey
        enterKey
        tKey
        spaceKey
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
        numTarg = 40
        Copy_Seq_Num
        channels = 1:16
        sourceType ='FT'
        classifierType ='CCA'
        spelledLetters
        spelledTxt
        running
        showStart = true
        trainFileName =[];
        predictiveText
        src_parallel_mode = false
        keypress_check_vector
        SUB_DATA
        data_dir
        
        % Speller Modes
        spellerMode = 'copyspell'
        debugMode = false
        wordPredictionMode = false
        twitterMode = false
        TTS_Mode = false
        showFeedback = true
        
        % PTB Screens
        offScreen
        blankScreen
        startScreen
        endScreen
        articleScreen
        articleInstructionScreen
        copySpellInstructionScreen
        passiveViewInstructionScreen
        
        % Class objects
        sourceObj
        classifierObj
        wordPredictorObj
        twitterObj
        TTS_Obj
        
        % speller article task
        standard_words = {'PIG','CAT','OWL','ANT','BEE','FOX','CAR','VAN','MUD','NUT','BED','TEA',...
            'EAT','ASK','RAN','BUY','SIT','DIG'};
        std_word_trials = 6;
        article_database
        article_database_file = 'data\stimuli_articles_task.csv';
        num_articles
        article_condition
        article_condition_text
        
    end
    
    methods
        %------------------------------------------------------------------
        % Class constructor:
        function self = speller(options)
            if(nargin==1)
                self.DEF_STIM_DUR = options.stimDuration;
                self.CUE_DUR = options.CUE_DUR;
                self.FB_DUR = options.FB_DUR;
                self.numTarg = options.numTarg;
                self.spellerMode = options.spellerMode;
                self.COPY_SEQ=options.copySeq;
                self.EXP_END = length(self.COPY_SEQ);
                self.sourceType = options.sourceType;
                self.classifierType = options.classifierType;
                self.channels = options.channels;
                self.showStart = options.showStart;
                self.debugMode = options.debugMode;
                self.trainFileName = options.trainFileName;
                self.wordPredictionMode = options.wordPredictionMode;
                self.twitterMode = options.twitterMode;
                self.TTS_Mode = options.TTS_Mode;
                self.src_parallel_mode = options.src_parallel_mode;
                self.SUB_DATA = options.SUB_DATA;
                self.data_dir = options.data_dir;
                self.showFeedback = options.showFeedback;
                % speller article task
                self.standard_words = options.standard_words;
            else
                % Get Subject Information
                getSubjectInfo(self);
            end
            Priority(1); % set to high priority
            initialize(self); % initialize speller display 
            Screen('Preference', 'SkipSyncTests', 1);
            
        end
        %------------------------------------------------------------------
        
        %------------------------------------------------------------------
        % Main Functions:
        
        % Get subject info
        function getSubjectInfo(self)
            % Open Dialog box to get subject ID and Session Number
            prompt = {'Enter Subject Initials (e.g. NRW)','Enter Session Number'};
            dlg_title = 'SubInfo';
            num_lines = 1;
            defaultans = {'XXX','1'};
            answer = inputdlg(prompt,dlg_title,num_lines,defaultans);
            self.SUB_DATA.sub_id=answer{1};
            self.SUB_DATA.session_num = str2double(answer{2});
            self.SUB_DATA.file_name = ['data/ExperimentData/Subject_' self.SUB_DATA.sub_id '_data.csv'];
            
            % If this is the subjects first session, generate an
            % experimental file for all sessions for this subject. If not,
            % load the existing subject experimental file
            if(self.SUB_DATA.session_num==1 && ~exist(self.SUB_DATA.file_name,'file'))
                [~,~,orig_stimuli] = xlsread(self.article_database_file);
                
                % Generate NY times stimuli order for all sessions
                all_ids = randperm(size(orig_stimuli,1)-1);
                social_ids = all_ids(1:30); %10 session, 3 articls per sesh
                nonSocial_ids = all_ids(31:60); %10 session, 3 articls per sesh
                social_ = reshape(social_ids,3,10);
                nonsocial_ = reshape(nonSocial_ids,3,10);
                
                redo = true;
                while redo
                    redo = false;
                    total_ = [social_ nonsocial_];
                    labels = [ones(1,length(social_)) zeros(1,length(nonsocial_))];
                    sesh_idx = randperm(20);
                    total_=total_(:,sesh_idx);
                    labels = labels(sesh_idx);
                    for win=1:length(labels)-3;
                        if(length(unique(labels(win:win+3)))==1)
                            redo = true;
                            break;
                        end
                    end
                end
                labels = labels';
                % new subject stimuli order 
                self.SUB_DATA.article_task(1,:) = {orig_stimuli{1,:}};
                cnt=1;
                for i=1:size(total_,2)
                    for j=1:size(total_,1)
                        self.SUB_DATA.article_task(cnt+1,:)={orig_stimuli{total_(j,i)+1,:}};
                        cnt=cnt+1;
                    end
                end
                self.SUB_DATA.article_task{1,9} = 'session';
                self.SUB_DATA.article_task{1,10} = 'condition';
                self.SUB_DATA.article_task{1,11} = 'result';
                cnt=1;
                for i=1:20
                    for j=1:3
                        self.SUB_DATA.article_task{cnt+1,9} = i;
                        self.SUB_DATA.article_task{cnt+1,10}=labels(i);
                        cnt=cnt+1;
                    end
                end
                
                % Generate Fixed Spelling Order for all sessions
                self.SUB_DATA.fixed_spell{1,1}='session';
                self.SUB_DATA.fixed_spell{1,2}='condition';
                self.SUB_DATA.fixed_spell{1,3}='word_num';
                self.SUB_DATA.fixed_spell{1,4}='word';
                self.SUB_DATA.fixed_spell{1,5}='result';
                cnt=1;
                for i=1:20
                    idx = randperm(18,12);
                    for j=1:length(idx)
                        self.SUB_DATA.fixed_spell{cnt+1,1} = i;
                        self.SUB_DATA.fixed_spell{cnt+1,2} = double(j>length(idx)/2);
                        self.SUB_DATA.fixed_spell{cnt+1,3} = idx(j);
                        self.SUB_DATA.fixed_spell{cnt+1,4} = self.standard_words{idx(j)};
                        cnt=cnt+1;
                    end
                end
                
                % Generate Passive Spelling Order for all sessions
                self.SUB_DATA.combination{1,1}='session';
                self.SUB_DATA.combination{1,2}='condition';
                cnt=1;
                for i = 1:20
                    for j=1:10
                        idx = randperm(4);
                        for k =1:length(idx)
                            self.SUB_DATA.combination{cnt+1,1} = i;
                            self.SUB_DATA.combination{cnt+1,2} = idx(k);
                            cnt=cnt+1;
                        end
                    end
                end
                
                % Generate Stroop Trials?
                
                % Save file 
                xlswrite(self.SUB_DATA.file_name,self.SUB_DATA.article_task,'article');
                xlswrite(self.SUB_DATA.file_name,self.SUB_DATA.fixed_spell,'fixed_spell');
                xlswrite(self.SUB_DATA.file_name,self.SUB_DATA.combination,'combination');
            end
            
            % Load Subject Experimental File and set paradigm
            [self.SUB_DATA.article_task_num,~,self.SUB_DATA.article_task] = xlsread(self.SUB_DATA.file_name,'article');
            [self.SUB_DATA.fixed_spell_num,~,self.SUB_DATA.fixed_spell] = xlsread(self.SUB_DATA.file_name,'fixed_spell');
            [self.SUB_DATA.combination_num,~,self.SUB_DATA.combination] = xlsread(self.SUB_DATA.file_name,'combination');
        end
        
        function initialize(self)
        % INITIALIZE starts up the PTB windows, speller screens and other
        % modules used to run the BCI speller
            
            % determine copy spell or free spell mode
            if(strcmpi(self.spellerMode,'freespell'))
                self.copy_seq=[];
            else
                self.wordPredictionMode = false; % only use WP in freespell
            end
            
            % determine if word completion mode
            if(self.wordPredictionMode)
                self.wordPredictorObj = WordPredictor();
                self.predictiveText = PredictWords(self.wordPredictorObj,[]);
            end 
            
            % determine if twitter mode
            if(self.twitterMode)
                self.twitterObj = TwitterApp();
            end
            
            % Init PTB and generate speller Screens
            exp_GenPTBscreens(self);
            
            % determin if TTS mode
            if(self.TTS_Mode)
                self.TTS_Obj = Text2Speech(self.design.NameAudio);
            end
            
            % initialize Signal Source module
            switch self.sourceType
                case 'FT'
                    self.sourceObj = FT(self.DEF_STIM_DUR,1,self.channels, self.debugMode,self.src_parallel_mode);
                case 'LSL'
                    self.sourceObj = LSL(self.DEF_STIM_DUR,1,self.channels, self.debugMode);
            end
            
            % initialize Classifier module
            switch self.classifierType
                case 'CCA'
                    self.classifierObj = CCA(self.numHarmonics,self.DEF_STIM_DUR,self.sourceObj.Fs,self.design.StimFreq, self.debugMode);
                case 'CombinedCCA'
                    self.classifierObj = Combined_CCA(self.numHarmonics,self.DEF_STIM_DUR,self.sourceObj.Fs,self.design.StimFreq, self.debugMode, self.trainFileName);
                case 'Mouse'
                    self.classifierObj = Mouse_Classifier(self.window,self.design.StimLoc);
            end
            
        end % END initialze
        
        function terminate(self)
        % TERMINATE closes all PTB windows and terminates any objects
            Screen('CloseAll');
            ShowCursor;
            Screen('Preference', 'VisualDebuglevel', 1);    
            % save results
            xlswrite(self.SUB_DATA.file_name,self.SUB_DATA.article_task,'article');
            xlswrite(self.SUB_DATA.file_name,self.SUB_DATA.fixed_spell,'fixed_spell');
            xlswrite(self.SUB_DATA.file_name,self.SUB_DATA.combination,'combination');
            
            % close out objects
            try
                terminate(self.sourceObj);
            catch
            end
            if(self.TTS_Mode)
                dispose(self.TTS_Obj);
            end
            Priority(0);
            
        end % END terminate
        
        function start(self)
        %START is the main runnable that starts and runs the speller after
        %all initialization has been completed 
        
            % Show start screen and wait for user to Start
            if(self.showStart)
                Screen('CopyWindow', self.startScreen, self.window);
                Screen('Flip', self.window);
                user_pause(self); % Pause
            end
            
             % STANDARD WORDS
            Screen('CopyWindow', self.copySpellInstructionScreen, self.window); 
            Screen('Flip', self.window);
            user_pause(self); % Pause
            idx = find((self.SUB_DATA.fixed_spell_num(:,1)...
                == self.SUB_DATA.session_num & self.SUB_DATA.fixed_spell_num(:,2) == 0));
            words = self.SUB_DATA.fixed_spell_num(idx,3);
            for w=1:length(words)
                run_copyspell_trial(self, self.standard_words{words(w)});
                % Save Results***
                self.SUB_DATA.fixed_spell{idx(w)+1,5} = self.fb_seq2;
            end
            
            % *TODO* Implement passive viewing paradigm, load and save
            % PASSIVE VIEWING
            Screen('CopyWindow', self.passiveViewInstructionScreen, self.window); 
            Screen('Flip', self.window);
            user_pause(self); % Pause
            run_passive_viewing(self);
            
            % ARTICLE - FREE SPELL 
            % display instruction screen
            idx = find(self.SUB_DATA.article_task_num(:,9) == self.SUB_DATA.session_num);
            condition = self.SUB_DATA.article_task_num(idx(1),10);
            Screen('CopyWindow', self.articleInstructionScreen, self.window);
            Screen('Flip', self.window);
            user_pause(self); % Pause
            for article = 1:length(idx)
                run_article_sequence(self,self.SUB_DATA.article_task{idx(article)+1,2},self.SUB_DATA.article_task{idx(article)+1,3},condition);
                run_freespell_trial(self,self.SUB_DATA.article_task{idx(article)+1,2});
                % Save Results***
                self.SUB_DATA.article_task{idx(article)+1,11} = self.fb_seq2;
            end
            
             % STANDARD WORDS
            Screen('CopyWindow', self.copySpellInstructionScreen, self.window);
            Screen('Flip', self.window);
            user_pause(self); % Pause
            idx = find((self.SUB_DATA.fixed_spell_num(:,1)...
                == self.SUB_DATA.session_num & self.SUB_DATA.fixed_spell_num(:,2) == 1));
            words = self.SUB_DATA.fixed_spell_num(idx,3);
            for w=1:length(words)
                run_copyspell_trial(self, self.standard_words{words(w)});
                % Save Results***
                self.SUB_DATA.fixed_spell{idx(w)+1,5} = self.fb_seq2;
            end
            
            % *TODO* implement stroop task, load and saving
            % STROOP
            
            % experiemnt complete, terminate
            terminate(self); % terminate speller when done
        end
        
        % this snippit runs a passive viewing
        function run_passive_viewing(self)
            % not yet implemented
        end
        
        %this function runs the ny times article sequence
        function run_article_sequence(self, article_headline, article_abstract,condition)
            % setup next article
            self.articleScreen = Screen(self.window, 'OpenOffScreenWindow', self.BG_COLOR);
            Screen(self.articleScreen, 'TextColor', self.WHITE);
            Screen(self.articleScreen, 'TextFont', self.TEXT_FONT);
            Screen(self.articleScreen, 'TextSize', self.FONT_SIZE);
            
            bounds = Screen('TextBounds',self.articleScreen ,self.article_condition_text{condition+1});
            Screen('DrawText', self.articleScreen, self.article_condition_text{condition+1},...
                self.centX-bounds(RectRight)/2, self.design.TxtFldLoc(4)-50, self.WHITE);
            bounds = Screen('TextBounds',self.articleScreen ,['"' article_headline '"']);
            Screen('DrawText', self.articleScreen, ['"' article_headline '"'],...
                self.centX-bounds(RectRight)/2, self.design.TxtFldLoc(4)+150, self.WHITE);
            DrawFormattedText(self.articleScreen,WrapString(article_abstract)...
                ,'center','center',[],[],[],[],2);
            
            % display article and wait for user to continue
            Screen('CopyWindow', self.articleScreen, self.window);
            Screen('Flip', self.window);
            user_pause(self); % pause
            
        end
        
        %this snippit runs a free spelling run
        function run_freespell_trial(self,optional_text)
            self.spellerMode = 'articlespell';
            self.fb_seq = []; self.fb_seq2=[]; self.copy_seq=optional_text;
            spelling=true;
            while(spelling)
                
                % Standard cue-stim-fb sequence
                displayCue(self);                    % CUE                
                spelling = user_pause(self);         % Pause
                if(spelling)
                    stimulate(self);                 % Stimulation
                    displayFeedback(self);           % Feedback
                end
                
            end
        end
        
        % this code snippet runs a copy spell run
        function run_copyspell_trial(self,word2spell)
            self.spellerMode = 'copyspell2';
            % spell until word is completely spelled
            self.TRIAL_CNT=1;
            self.COPY_SEQ = word2spell;
            self.fb_seq = []; self.fb_seq2 = [];
            % translate txt 2 spell 2 number array
            for xx = 1:length(self.COPY_SEQ)
                for jj = 1:length(self.design.Symbol)
                    if(strcmp(self.design.Symbol{jj},self.COPY_SEQ(xx)))
                        self.Copy_Seq_Num(xx) = jj;
                    end
                end
            end
            
            while(self.TRIAL_CNT <=length(word2spell))
                
                % Standard cue-stim-fb sequence
                displayCue(self);                    % CUE
                user_pause(self)                     % Pause
                stimulate(self);                     % Stimulation
                displayFeedback(self);               % Feedback
                
                % update trial counter
                self.TRIAL_CNT = self.TRIAL_CNT + 1;
            end
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
                if keyCode(self.enterKey) || keyCode(self.tKey)
                    keepGoing = true;
                    KbReleaseWait;
                    break;
                end
            end
        end
        
        % Drawing Functions
        function preDrawStimuli(self)
        % PREDRAWSTIMULI Pre-Draws stimulus sequence in off-screens in the background
            for win_i = 1:1:self.design.LenCode
                Screen('FillRect', self.offScreen(win_i), self.WHITE, self.design.TxtFldLoc);
                
                if(strcmpi(self.spellerMode,'copyspell') || strcmpi(self.spellerMode,'articlespell'))
                    Screen('DrawText', self.offScreen(win_i), ['>>' self.fb_seq], self.design.TxtLocX, self.design.TxtLocY+diff(self.design.TxtFldLoc([2,4]))/4, self.BLACK);
                    Screen('DrawText', self.offScreen(win_i), ['>>' self.copy_seq], self.design.TxtLocX, self.design.TxtLocY-diff(self.design.TxtFldLoc([2,4]))/4, self.BLACK);
                else
                    Screen('DrawText', self.offScreen(win_i), ['>>' self.fb_seq], self.design.TxtLocX, self.design.TxtLocY, [0, 0, 0]); 
                end
                
                if(self.wordPredictionMode)
                    fillColor = cell2mat(self.design.FlickCode');
                    stimParam = struct(...
                        'FillColor',    fillColor(:, win_i),...
                        'FrameColor',   fillColor(:, win_i),...
                        'TextColor',    self.BLACK,...
                        'TextFont',     self.TEXT_FONT,...
                        'TextSize',     self.FONT_SIZE);
                    exp_preloadStimuli(self,'stimuli', self.offScreen(win_i), self.design, stimParam)
                end
            end % win_i
        end
        
        function stimulate(self)
        % STIMULATE starts the actual ssvep stimulation sequence. this is a
        % synchronous and discrete speller, therefore, the stimulation
        % turns on and off for a fixed interval, afterwards, classification
        % and feedback can be performed
            self.vbl = Screen('Flip', self.window);
            if(strcmp(self.sourceType,'LSL'))
                if(strcmp(self.spellerMode,'copyspell'))
                    sendStartMarker(self.sourceObj, ['trial_start_#' int2str(self.TRIAL_CNT-1) '_char_'...
                        self.COPY_SEQ(self.TRIAL_CNT-1) '_freq_' num2str(self.design.StimFreq{self.Copy_Seq_Num(self.TRIAL_CNT-1)})]);
                else                    
                    sendStartMarker(self.sourceObj, 'trial_start');
                end
            else
                sendTrigger(self.sourceObj,'start'); % trigger start of stimulation
            end
            
            % Start Gazing (Stimulation) ------------------------------------
            for win_i = 1:1:self.design.LenCode
                % If 'ESC' key is pressed, the iteration will be finished.
                [~, ~, keyCode] = KbCheck([],[],self.keypress_check_vector);
                if keyCode(self.escKey), break; end
                % Stimulation
                Screen('CopyWindow', self.offScreen(win_i), self.window);
                self.vbl = Screen('Flip', self.window, self.vbl + (0.5*self.ifi));
                
                if(strcmp(self.classifierType,'Mouse'))
                    % decode selected target from mouse click
                    decode_mouse_target(self.classifierObj)
                end
            end % win_i

            if(strcmp(self.sourceType,'LSL'))
                if(strcmp(self.spellerMode,'copyspell'))
                    sendStopMarker(self.sourceObj, ['trial_stop_#' int2str(self.TRIAL_CNT-1) '_char_'...
                        self.COPY_SEQ(self.TRIAL_CNT-1) '_freq_' num2str(self.design.StimFreq{self.Copy_Seq_Num(self.TRIAL_CNT-1)})]);
                else
                    sendStopMarker(self.sourceObj, 'trial_stop');
                end
            else
                sendTrigger(self.sourceObj,'stop');   % trigger end of stimulation
            end
            Screen('CopyWindow', self.blankScreen, self.window); 
            Screen('Flip', self.window); % return to blank screen after stimulation
        end
        
        function displayCue(self)
        % DISPLAYCUE displays the cue to the next letter to spell to the
        % user. This is usually used in copy-speller mode
            trialStart = tic;  % Timer for begining of trial
            
            if(strcmpi(self.spellerMode,'copyspell'))
                % Cue Letter to Spell (Copy Spelling Mode)
                Txt2Spell = self.COPY_SEQ(self.TRIAL_CNT);
                self.copy_seq = [self.COPY_SEQ '  (' Txt2Spell ')' ];
                cue = self.Copy_Seq_Num(self.TRIAL_CNT);
                
                % Display Cue to user
                exp_visualFeedback(self,self.blankScreen, self.design, cue, self.BLUE, self.BLUE, self.WHITE, self.fb_seq,self.copy_seq);
                Screen('CopyWindow', self.blankScreen, self.window);
                Screen('Flip', self.window);
                
                % return fb and cue stim to normal for stimulation
                exp_visualFeedback(self,self.blankScreen, self.design, cue, self.BLACK, self.WHITE, self.WHITE, self.fb_seq, self.copy_seq);
            elseif(strcmpi(self.spellerMode,'copyspell2'))
                self.copy_seq = self.COPY_SEQ;
                exp_visualFeedback(self,self.blankScreen, self.design, 1, self.BLACK, self.WHITE, self.WHITE, self.fb_seq, self.copy_seq);
                Screen('CopyWindow', self.blankScreen, self.window);
                Screen('Flip', self.window);
                
            elseif(strcmpi(self.spellerMode,'articlespell'))
                exp_visualFeedback(self,self.blankScreen, self.design, 1, self.BLACK, self.WHITE, self.WHITE, self.fb_seq, self.copy_seq);
                Screen('CopyWindow', self.blankScreen, self.window);
                Screen('Flip', self.window);
            else
                % Update Word Prediction
                if(self.wordPredictionMode)
                    if(~isempty(self.fb_seq))
                        wp = strsplit(self.fb_seq);
                        self.predictiveText = PredictWords(self.wordPredictorObj,wp{end});
                    else 
                        self.predictiveText = PredictWords(self.wordPredictorObj,[]);
                    end
                    % update the first 9 stimuli of blank screen with new
                    % predictive text
                    for i = 1:self.wordPredictorObj.numWords2Predict
                        self.design.Symbol{i} = [' ' upper(self.predictiveText{i}) ' '];
                        self.design.NameAudio{i} = self.predictiveText{i};
                        Screen(self.blankScreen, 'TextSize', self.SM_FONT_SIZE);
                        exp_visualFeedback(self, self.blankScreen, self.design, i, self.BLACK, self.YELLOW, self.YELLOW, self.fb_seq,[]);
                    end
                        Screen(self.blankScreen, 'TextSize', self.FONT_SIZE);
                else
                    exp_visualFeedback(self,self.blankScreen, self.design, 1, self.BLACK, self.WHITE, self.WHITE, self.fb_seq, []);
                end
                
                Screen('CopyWindow', self.blankScreen, self.window);
                Screen('Flip', self.window);
            end

            preDrawStimuli(self);  % pre-draw
            while toc(trialStart) <= self.CUE_DUR
                [~, ~, keyCode] = KbCheck([],[],self.keypress_check_vector);
                if keyCode(self.escKey), break; end
            end
        end
        
        function displayFeedback(self)
        % DISPLAYFEEDBACK performs all opterations necessary to generate
        % feedback for an SSVEP speller, including extracting a stimulus
        % time-locked EEG trial, classifiying the EEG trial, and displaying
        % the feedback to the user.
            if(self.showFeedback)
                % Determine feedback
                trial = readBuffer(self.sourceObj); % extract EEG trial from source
                fb = classifyTrial(self.classifierObj,trial); % classify trial
                self.spelledLetters = [self.spelledLetters fb]; % save spelled leters
                self.spelledTxt = [self.spelledTxt self.design.fbSymbol{fb}];

                % Dispaly feedback to user
                if(self.twitterMode && fb == self.twitterObj.twitterTarg)
                    sendTweet(self.twitterObj,self.fb_seq);
                    show_twitter(self.twitterObj);
                    self.TRIAL_CNT=self.EXP_END+1;
                else
                    if(strcmp(self.design.Symbol{fb},'<') && ~strcmp(self.spellerMode,'copyspell2'))
                        self.fb_seq = self.fb_seq(1:end-1);
                        self.fb_seq2 = [self.fb_seq2, self.design.fbSymbol{fb}];
                    else
                        self.fb_seq = [self.fb_seq, self.design.fbSymbol{fb}];
                        self.fb_seq2 = [self.fb_seq2, self.design.fbSymbol{fb}];
                    end
                end

                % Re-Draw Screen with new feedback
                if(self.wordPredictionMode && fb <=9)
                    Screen(self.blankScreen, 'TextSize', self.SM_FONT_SIZE);
                else
                    Screen(self.blankScreen, 'TextSize', self.FONT_SIZE);
                end
                exp_visualFeedback(self, self.blankScreen, self.design, fb, self.RED, self.RED, self.BLACK, self.fb_seq,self.copy_seq);
                Screen('CopyWindow', self.blankScreen, self.window);
                Screen('Flip', self.window);

                if(self.TTS_Mode)
                    play_text(self.TTS_Obj,fb);
                end

                % Reset screen after display
                if(self.wordPredictionMode && fb <=9)
                    Screen(self.blankScreen, 'TextSize', self.SM_FONT_SIZE);
                end
                exp_visualFeedback(self, self.blankScreen, self.design, fb, self.BLACK, self.WHITE, self.WHITE, self.fb_seq,self.copy_seq);
                Screen(self.blankScreen, 'TextSize', self.FONT_SIZE);
            end
            inter_trialStart = tic;
            while toc(inter_trialStart) <= self.FB_DUR
                [~, ~, keyCode] = KbCheck([],[],self.keypress_check_vector);
                if keyCode(self.escKey), break; end
            end
        end
        %------------------------------------------------------------------
        
        
        %------------------------------------------------------------------
        % Dependencies:
        
        function exp_GenPTBscreens(self)
        % EXP_GENPTBSCREENS generates the main PTB screens used for
        % stimulation and for start and end of experiments. It
        % pre-generates and pre-loads all screens and frames into memory
        % for fast swapping in real-time
            % Initialize PTB toolbox
            if(~strcmp(self.classifierType,'Mouse')) 
                HideCursor;
            end
            KbName('UnifyKeyNames');
            self.escKey = KbName('ESCAPE');
            self.enterKey = KbName('Return');
            self.tKey = KbName('t');
            self.spaceKey = KbName('SPACE');
            self.keypress_check_vector = zeros(1,256);
            self.keypress_check_vector([self.escKey, self.enterKey, self.tKey, self.spaceKey]) = 1; 
            self.oldDebugLevel = Screen('Preference', 'VisualDebuglevel', 1);
            self.screens = Screen('Screens');
            self.screenNumber = max(self.screens);
            [self.window, self.windowRect] = Screen('OpenWindow', self.screenNumber, self.BG_COLOR, [], [], 2);
            [self.centX, self.centY] = RectCenter(self.windowRect);
            self.ifi = Screen('GetFlipInterval', self.window);
            self.refreshRateHz = round(1/self.ifi);
            display(['Da frequency is : ' num2str(self.refreshRateHz)]);
            % Generate Stimulus design structur
            self.design = exp_GenStimDesign(self,self.spellerMode, self.refreshRateHz, [self.windowRect(3), self.windowRect(4)], self.DEF_STIM_DUR, self.numTarg);
            % translate txt 2 spell 2 number array
            for xx = 1:length(self.COPY_SEQ)
                for jj = 1:length(self.design.Symbol)
                    if(strcmp(self.design.Symbol{jj},self.COPY_SEQ(xx)))
                        self.Copy_Seq_Num(xx) = jj;
                    end
                end
            end
            self.design.CentWindow = [self.centX, self.centY];
            % -------------------------------------------------------------
            % Set Stimulus and text coordinates for stimulation screen
            % -------------------------------------------------------------
            for targ_i = 1:1:self.design.NumTarg  
                % Set coordinates of rectangle vertex
                % [left upper X, left upper Y, right lower X, right lower Y]
                self.design.StimLoc{targ_i} = [...
                    self.design.CenterLoc{targ_i}(1) + self.centX - self.design.LenSide/2,...
                    self.design.CenterLoc{targ_i}(2) + self.centY - self.design.LenSide/2,...
                    self.design.CenterLoc{targ_i}(1) + self.centX + self.design.LenSide/2,...
                    self.design.CenterLoc{targ_i}(2) + self.centY + self.design.LenSide/2];
                
                % Set cordinates of text location
                bounds = Screen(self.window, 'TextBounds', self.design.Symbol{targ_i});
                if(self.wordPredictionMode && targ_i <=9)
                    % make the predictive words left justified
                    self.design.TextLocX{targ_i} = self.design.CenterLoc{targ_i}(1)+self.centX-bounds(RectRight)/1.5;
                else
                    self.design.TextLocX{targ_i} = self.design.CenterLoc{targ_i}(1)+self.centX-bounds(RectRight)/1.5;
                end
                self.design.TextLocY{targ_i} = self.design.CenterLoc{targ_i}(2)+self.centY-bounds(RectBottom)/1.5;
                
            end % targ_i
            % Set coordinates of text filed for visual feedback
            % [left upper X, left upper Y, right lower X, right lower Y]
            self.design.TxtFldLoc = [...
                self.design.LocTxtFld(1) + self.centX - self.design.wTxtFld/2,...
                self.design.LocTxtFld(2) + self.centY - self.design.hTxtFld/2,...
                self.design.LocTxtFld(1) + self.centX + self.design.wTxtFld/2,...
                self.design.LocTxtFld(2) + self.centY + self.design.hTxtFld/2];
            self.design.TxtFldLoc(2)=self.design.TxtFldLoc(2) - 10;
            self.design.TxtFldLoc(4)=self.design.TxtFldLoc(4) - 10;
            bounds = Screen(self.window, 'TextBounds', '>>');
            self.design.TxtLocX = self.design.TxtFldLoc(1)+bounds(RectRight)/2+10;
            self.design.TxtLocY = mean(self.design.TxtFldLoc([2,4]))-bounds(RectBottom)/2;
            
            % -------------------------------------------------------------
            % Set offscreen for stimulation
            % -------------------------------------------------------------
            fillColor = cell2mat(self.design.FlickCode');
            self.offScreen = zeros(1, self.design.LenCode);
            for win_i = 1:1:self.design.LenCode
                
                % Open off-screens
                stimParam = struct(...
                    'FillColor',    fillColor(:, win_i),...
                    'FrameColor',   fillColor(:, win_i),...
                    'TextColor',    self.BLACK,...
                    'TextFont',     self.TEXT_FONT,...
                    'TextSize',     self.FONT_SIZE);
                
                self.offScreen(win_i) = Screen(self.window, 'OpenOffScreenWindow', self.BG_COLOR);
                exp_preloadStimuli(self,'stimuli', self.offScreen(win_i), self.design, stimParam);
                
            end % win_i
            % -------------------------------------------------------------
            % Set blankscreen
            % -------------------------------------------------------------
            % Set offscreen for gaze shift
            stimParam = struct(...
                'FillColor',    self.BLACK,...
                'FrameColor',   self.WHITE,...
                'TextColor',    self.WHITE,...
                'TextFont',     self.TEXT_FONT,...
                'TextSize',     self.FONT_SIZE);
            
            self.blankScreen = Screen(self.window, 'OpenOffScreenWindow', self.BG_COLOR);
            exp_preloadStimuli(self,'blank', self.blankScreen, self.design, stimParam);
            % ---------------------------------------------------------------------
            % Create offscreen for start screen
            % ---------------------------------------------------------------------
            self.startScreen = Screen(self.window, 'OpenOffScreenWindow', self.BG_COLOR);
            
            Screen(self.startScreen, 'TextColor', self.WHITE);
            Screen(self.startScreen, 'TextFont', self.TEXT_FONT);
            Screen(self.startScreen, 'TextSize', self.FONT_SIZE);
            
            startMsg = ['You are about to start the daily experiment. In this session, you will copy-spell six three-letter' ...
                ' words, passively view stimuli, and summarize three NY times articles. \n This experiment is self paced. ' ...
                'For every pause, press "ENTER" to continue. During the free spell portions, press'...
                ' "ESC" when finished spelling. If you are unsure about any part of the task, plase ask the experimenter for clarification. /n'...
                ' Press "ENTER" to begin'];  
            
            DrawFormattedText(self.startScreen,WrapString(startMsg),'center','center',[],[],[],[],2);
            
            % ---------------------------------------------------------------------
            % Create offscreen for Ending screen
            % ---------------------------------------------------------------------
            self.endScreen = Screen(self.window, 'OpenOffScreenWindow', self.BG_COLOR);
            
            Screen(self.endScreen, 'TextColor', self.WHITE);
            Screen(self.endScreen, 'TextFont', self.TEXT_FONT);
            Screen(self.endScreen, 'TextSize', self.FONT_SIZE);
            
            endMsg = 'Experiment Complete. Press the "ESCAPE" key to close.';
            bounds = Screen(self.endScreen, 'TextBounds', endMsg);
            Screen('DrawText', self.endScreen, endMsg, self.centX-bounds(RectRight)/2, self.centY-bounds(RectBottom)/2, self.WHITE);
            
            % ---------------------------------------------------------------------
            % Create offscreen for NY times article screen
            % ---------------------------------------------------------------------
            self.articleScreen = Screen(self.window, 'OpenOffScreenWindow', self.BG_COLOR);
            
            Screen(self.articleScreen, 'TextColor', self.WHITE);
            Screen(self.articleScreen, 'TextFont', self.TEXT_FONT);
            Screen(self.articleScreen, 'TextSize', self.FONT_SIZE);
            
            headline = ['Low-Fat Diet May Ease Hot Flashes'];
            abstract = ['A study suggests that weight loss with a low-fat, high fruit and vegetable diet may help reduce or eliminate hot flashes and night sweats associated with menopause.'];
            
            bounds = Screen(self.articleScreen, 'TextBounds',headline);
            Screen('DrawText', self.articleScreen, headline, self.centX-bounds(RectRight)/2, self.design.TxtFldLoc(4), self.WHITE);
            DrawFormattedText(self.articleScreen,WrapString(abstract),'center','center',[],[],[],[],2);
            
            % ---------------------------------------------------------------------
            % Create instruction screen for article task
            % ---------------------------------------------------------------------
            self.articleInstructionScreen = Screen(self.window, 'OpenOffScreenWindow', self.BG_COLOR);
            
            Screen(self.articleInstructionScreen, 'TextColor', self.WHITE);
            Screen(self.articleInstructionScreen, 'TextFont', self.TEXT_FONT);
            Screen(self.articleInstructionScreen, 'TextSize', self.FONT_SIZE);
            
            self.article_condition_text{1}='Share this article with your Twitter followers by saying something about it';
            self.article_condition_text{2}='Write the first few words of headline';
            
            general_instruction_text='Next, you will read three short NY times articles and perform a free spelling about the article. Press "ESC" when done spelling.';
            DrawFormattedText(self.articleInstructionScreen,WrapString(general_instruction_text),'center','center',[],[],[],[],2);
            
            % ---------------------------------------------------------------------
            % Create instruction screen for standard word, copy speller task
            % ---------------------------------------------------------------------
            self.copySpellInstructionScreen = Screen(self.window, 'OpenOffScreenWindow', self.BG_COLOR);
            
            Screen(self.copySpellInstructionScreen, 'TextColor', self.WHITE);
            Screen(self.copySpellInstructionScreen, 'TextFont', self.TEXT_FONT);
            Screen(self.copySpellInstructionScreen, 'TextSize', self.FONT_SIZE);
            instruction_text = 'Please spell the indicated word. For each letter, visually attend to the letter during stimulation. Press enter to begin the stimulation for each letter.';
            DrawFormattedText(self.copySpellInstructionScreen,WrapString(instruction_text),'center','center',[],[],[],[],2);
            
            % ---------------------------------------------------------------------
            % Create instruction screen for passive viewing task
            % ---------------------------------------------------------------------
            self.passiveViewInstructionScreen = Screen(self.window, 'OpenOffScreenWindow', self.BG_COLOR);
            
            Screen(self.passiveViewInstructionScreen, 'TextColor', self.WHITE);
            Screen(self.passiveViewInstructionScreen, 'TextFont', self.TEXT_FONT);
            Screen(self.passiveViewInstructionScreen, 'TextSize', self.FONT_SIZE);
            instruction_text = 'Passive Viewing Section. Please press "ENTER" and fixate on the cross. (Not yet implemented...)';
            DrawFormattedText(self.passiveViewInstructionScreen,WrapString(instruction_text),'center','center',[],[],[],[],2);
            
        end %END exp_GenPTBscreens
        
        function design = exp_GenStimDesign(self,spellerMode, refresh, resol, stimTime,numTarg)
        %EXP_GENSTIMDESIGN generates a stimulus design structure that
        %contains all of the parameters for the ssvep speller stimulus
        %including the frequency/phase properties of the stimuli
            % stimulus parameters
            DEFAULT_PHASE   = 0.001;
            wid         = resol(1);     % width of screen window
            hei         = resol(2);     % height of screen window
            lenCode     = round(refresh*stimTime);
            numFreq     = numTarg;
            minFreq     = 8.0;
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
                    stimPhase{numColumn*(row_i-1)+column_i} = wrapTo2Pi(minPhase + phaseResol*(numRow*(column_i-1)+(row_i-1)));
                end % row_i
            end % column_i
            
            % set stim frequencies to: 7Hz - 15.8Hz spaced 0.2Hz apart (45)
            % skipping 7.8, 9.4, 11, 12.6, 14.2 (40 total)            
            stimFreqTmp = [7:0.2:7.6 8.0:0.2:9.2 9.6:0.2:10.8 11.2:0.2:12.4 12.8:0.2:14.0 14.4:0.2:15.8];
            
            % randomize (randomize in groups of mid, low and high)
            stimFreqTmp = [stimFreqTmp(randperm(14)) stimFreqTmp(randperm(14)+14) stimFreqTmp(randperm(12)+28)];
            
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
                '$',':',';','(',')',' ','@','#','&','<'};
            
            % File name for audio files
            tmpNameAudio   = {'1', '2', '3', '4', '5', '6', '7', '8', '9', '0',...
                'Q', 'W', 'E', 'R', 'T', 'Y', 'U', 'I', 'O', 'P',...
                'A', 'S', 'D', 'F', 'G', 'H', 'J', 'K', 'L', 'space',...
                'Z', 'X', 'C', 'V', 'B', 'N', 'M', 'comma', 'period', 'Back Space'};

            eraseTarg   = numTarg;
            enterTarg   = numTarg+1; % It's dummy
            
            if(self.twitterMode)
                tmpSymbol{end} = 'Tweet';
                tmpNameAudio{end} = 'Message Tweeted';
                self.twitterObj.twitterTarg = numTarg;
                % add in backspace
                tmpSymbol{10} = '<';
                tmpNameAudio{10} = 'Back Space';
            end
            
            if(self.wordPredictionMode)   
                for i = 1:self.wordPredictorObj.numWords2Predict
                    tmpSymbol{i} = [' ' upper(self.predictiveText{i}) ' '];
                    tmpNameAudio{i} = self.predictiveText{i};
                end
            end
            
            for i=1:numTarg
                symbol{i} = tmpSymbol{i};
                fbSymbol{i} = tmpSymbol{i};
                if(strcmp(fbSymbol{i},'space') || strcmp(fbSymbol{i},'Tweet'))
                    fbSymbol{i} = ' ';
                end
                nameAudio{i} = tmpNameAudio{i};
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
            
            % Stimuli location
            if mod(numColumn,2) == 0        % In the case that the number of column is even
                for row_i = 1:1:numRow
                    for column_i = 1:1:numColumn
                        centerLoc{numColumn*(row_i-1)+column_i} =...
                            [hBlockSize*(column_i-numColumn/2) - hBlockSize/2,...
                            blockSize/2 + blockSize*(row_i-1) + blockSize/2 - (blockSize/2*(2*numRow+1)/2)];
                    end % row_i
                end % column_i
            elseif mod(numColumn,2) ~= 0    % In the case that the number of column is odd
                for row_i = 1:1:numRow
                    for column_i = 1:1:numColumn
                        centerLoc{numColumn*(row_i-1)+column_i} =...
                            [hBlockSize*(column_i-(floor(numColumn/2)+1)),...
                            blockSize/2 + blockSize*(row_i-1) + blockSize/2 - (blockSize/2*(2*numRow+1)/2)];
                    end % row_i
                end % column_i
            end
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
            
            design = struct('ModelName' ,spellerMode,...
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
                'NumColumn' ,{numColumn},...
                'EraseTarg' ,{eraseTarg},...
                'EnterTarg' ,{enterTarg},...
                'NameAudio' ,{nameAudio});
        end % - END exp_GenStimDesign
        
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
%                     tmp = square(2*pi*freq*(index/refresh)+phase, duty);
                    tmp = square(2*freq*(index/refresh)*pi+phase, duty);
                    code = (tmp>=0);
                    
                    % Generate flicker code based on sampled sinusoidal wave
                case 'sinusoid'
                    index = 0:1:clen-1;
                    tmp = sin(2*pi*freq*(index/refresh)+phase);
                    %tmp = cos(2*pi*freq*(index/refresh)+phase);
                    code = (tmp+1)/2;
                    
            end % switch model
        end % END exp_GenFlickerCode
        
        function exp_preloadStimuli(self,type, winObj, design, param)
        % EXP_PRELOADSTIMULI preloads the rectanular squares and text for
        % each frame and for each stimuli and draws them on the offscreen,
        % such that the pre-drawn screens can be easily flipped into view.
            Screen(winObj, 'TextColor', param.TextColor);
            Screen(winObj, 'TextFont', param.TextFont);
            Screen(winObj, 'TextSize', param.TextSize);
            
            %Screen('FillRect', winObj, param.FrameColor, design.txtFldLoc);
            for targ_i = 1:1:design.NumTarg
                
                % Set code
                if strcmp(type, 'stimuli')
                    fillColor = repmat(param.FillColor(targ_i),1,3)*255;
                    frameColor = repmat(param.FrameColor(targ_i),1,3)*255;
                elseif strcmp(type, 'blank')
                    fillColor = param.FillColor;
                    frameColor = param.FrameColor;
                end
                
                % Present stimuli
                Screen('FillRect', winObj, fillColor, design.StimLoc{targ_i});
                Screen('FrameRect', winObj, frameColor, design.StimLoc{targ_i});   % Draw rectangle
                if(self.wordPredictionMode && targ_i <= 9)
                    Screen(winObj, 'TextSize', self.SM_FONT_SIZE);
                else
                    Screen(winObj, 'TextSize', self.FONT_SIZE);
                end
                Screen('DrawText', winObj, design.Symbol{targ_i}, design.TextLocX{targ_i}, design.TextLocY{targ_i}, param.TextColor);  % Draw text
                
                
            end % targ_i
            
            % Draw text field for visual feedback
            Screen('FillRect', winObj, [255, 255, 255], design.TxtFldLoc);
            
            % Set feedback text location
            Screen('DrawText', winObj, '>>', design.TxtLocX, design.TxtLocY, [0, 0, 0]);
            
        end % END exp_preloadStimuli
        
        function exp_visualFeedback(self,winObj, design, target, fillColor, frameColor, fontColor, fb_seq, copy_seq)
        % EXP_VISUALFEEDBACK is a fucntion that changes the parameters of a
        % single stimulus target (specified by target), such that it can be
        % used to provide visual feedback to the user. it also changes the
        % text box to display the new feedback character and cue char. 
            if nargin > 7 && ~isempty(copy_seq) % copy speller mode
                Screen('FillRect', winObj, fillColor, design.StimLoc{target}); % highlight the selected target square
                Screen('FrameRect', winObj, frameColor, design.StimLoc{target}); % highligh border of selected target
                Screen('DrawText', winObj, design.Symbol{target}, design.TextLocX{target}, design.TextLocY{target}, fontColor); % re-draw text of target
                Screen('FillRect', winObj, [255, 255, 255], design.TxtFldLoc); % fill in text feedback window with white
                Screen(winObj, 'TextSize', self.FONT_SIZE); % always have TextWindow text regular size
                Screen('DrawText', winObj, ['>>' copy_seq], design.TxtLocX, design.TxtLocY-diff(design.TxtFldLoc([2,4]))/4, [0, 0, 0]);  
                Screen('DrawText', winObj, ['>>' fb_seq], design.TxtLocX, design.TxtLocY+diff(design.TxtFldLoc([2,4]))/4, [0, 0, 0]);
            else % - free spell mode
                Screen('FillRect', winObj, fillColor, design.StimLoc{target});
                Screen('FrameRect', winObj, frameColor, design.StimLoc{target});
                Screen('DrawText', winObj, design.Symbol{target}, design.TextLocX{target}, design.TextLocY{target}, fontColor);
                Screen(winObj, 'TextSize', self.FONT_SIZE); % always have TextWindow text regular size
                Screen('FillRect', winObj, [255, 255, 255], design.TxtFldLoc);
                Screen('DrawText', winObj, ['>>' fb_seq], design.TxtLocX, design.TxtLocY, [0, 0, 0]); 
            end
        end % END exp_visualFeedback
        %------------------------------------------------------------------  
    end
    
    
end