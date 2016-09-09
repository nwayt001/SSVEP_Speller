classdef (Abstract) base_classifier < handle
% BASECLASSIFIER is a parent class for all EEG classifiers
    properties
        type
        responses
        debugMode
    end
    
    methods
        %------------------------------------------------------------------
        % Class constructor:
        function self = base_classifier(type,debugMode)
            self.type = type;
            self.debugMode = debugMode;
        end
        %------------------------------------------------------------------
    end
    
    methods (Abstract)
        classifyTrial(self)
        %CLASSIFY 
    end
end
