classdef Text2Speech < handle
%TEXT2SPEECH is a class for text2speech synthisis for the SSVEP speller
    properties
        SV
        text_matrix
        audioPlayer_library
        fs = 16000;
        SV_preRecord
    end
    
    methods
        %------------------------------------------------------------------
        % Class constructor:
        function self = Text2Speech(text_matrix)
        % TEXT2SPEECH is the class constructor that instantiates the object
        % and initializes the text2speech
        
        % currently, the tts will just use the default MS 32 voice
        if ~ispc, error('Microsoft Win32 SAPI is required.'); end
        
        self.text_matrix = text_matrix; % text matrix for the speller
        self.SV = actxserver('SAPI.SpVoice');
        self.SV_preRecord = actxserver('SAPI.SpVoice');
        initialize(self);     % initialize tts pre-recorded speech
        end
        %------------------------------------------------------------------
        
        %------------------------------------------------------------------
        % Main Functions:
        function initialize(self)
            % initialize the audioPlayer_library with tts from the text
            % matrix
            for i = 1:length(self.text_matrix)
                MS = actxserver('SAPI.SpMemoryStream');
                MS.Format.Type = sprintf('SAFT%dkHz16BitMono',fix(self.fs/1000));
                self.SV_preRecord.AudioOutputStream = MS;
                self.SV.Rate = -5; % speak a bit slower than normal
                % Convert uint8 to double precision;
                invoke(self.SV_preRecord,'Speak',self.text_matrix{i});
                wav = reshape(double(invoke(MS,'GetData')),2,[])';
                wav = (wav(:,2)*256+wav(:,1))/32768;
                wav(wav >= 1) = wav(wav >= 1)-2;
                delete(MS);
                self.audioPlayer_library{i} = audioplayer(wav,self.fs);
            end
        end
        
        function speak_text(self,txt)
        %SPEAK_TEXT speaks text 'on the fly' (slower)
            invoke(self.SV,'Speak',txt);
        end
        
        function play_text(self,matrix_index)
        %PLAY_TEXT plays pre-recorded text from an audiolibrary (faster)
            play(self.audioPlayer_library{matrix_index});
        end
        
        function dispose(self)
        %DISPOSE is a garbage collection function
            delete(self.SV);
            delete(self.SV_preRecord);
            clear audioPlayer_library SV SV_preRecord;
        end
        %------------------------------------------------------------------
    end
end