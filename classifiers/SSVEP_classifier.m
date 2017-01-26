classdef (Abstract) SSVEP_classifier < base_classifier
    properties 
        yRef
        harmonics
        trialLength
        Fs
        freqs 
    end
    
    methods
        %------------------------------------------------------------------
        % Class constructor:
        function self = SSVEP_classifier(type,harmonics,trialLength,Fs,freqs,debugMode)
            self@base_classifier(type,debugMode);
            self.harmonics = harmonics;
            self.trialLength = trialLength;
            self.freqs = freqs;  
            if(debugMode)
                self.Fs = 256;
            else
                self.Fs = Fs;
            end
            build_sinusoids(self); 
        end
        %------------------------------------------------------------------
        
        %------------------------------------------------------------------
        % Dependencies:
        
        function build_sinusoids(obj)
        %BUILD_SINUSOIDS constructs the sine and cosine template signals
        %for each ssvep stimulation frequency
                t = 1/obj.Fs:1/obj.Fs:obj.trialLength;
                % frequency templates
                for i=1:length(obj.freqs)
                    cnt=1;
                    for j=1:obj.harmonics
                        obj.yRef(i,:,cnt)=sin(2*pi*obj.freqs{i}*j*t);
                        cnt=cnt+1;
                        obj.yRef(i,:,cnt)=cos(2*pi*obj.freqs{i}*j*t);
                        cnt=cnt+1;
                    end
                end
        end
        
        function terminate(~)
        % terminate function
        end
        %------------------------------------------------------------------
    
    end
end