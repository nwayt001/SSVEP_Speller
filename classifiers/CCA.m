classdef CCA < SSVEP_classifier
    properties
        testProp = 5;
    end
    
    methods
        %------------------------------------------------------------------
        % Class constructor:
        function self = CCA(harmonics,trialLength,Fs,freqs,debugMode)
            self@SSVEP_classifier('CCA',harmonics,trialLength,Fs,freqs,debugMode);
        end
        %------------------------------------------------------------------
        
        
        %------------------------------------------------------------------
        % Dependencies:
        
        function y = classifyTrial(obj,X)
        % CLASSIFY using CCA method. X is a single SSVEP trial to be 
        % classified [ timepoints x channels ]
        if(obj.debugMode)
            y = randi(size(obj.yRef,1));
            return
        end
        for i = 1:size(obj.yRef,1)
            [~,~,r(:,i)] = canoncorr(X,squeeze(obj.yRef(i,1:size(X,1),:)));
        end
        [~, y]=max(r(1,:));
        end
        
        %------------------------------------------------------------------
    end
end