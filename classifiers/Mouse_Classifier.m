classdef Mouse_Classifier < base_classifier
%MOUSECLASSIFIER This is a mouse classifier for the SSVEP speller 
% application. The classifies which speller target letter/stimulus is
% currently being selected via the computer mouse. This is intended for
% debugging the speller as it allows to manually selectet targets. 

    properties
        window  %handle to the current window
        selected_target = 1; % default
        StimLoc %rectangle location of each speller stimulus
    end
    
    methods
        %------------------------------------------------------------------
        % Class constructor:
        function self = Mouse_Classifier(window,StimLoc)
            self@base_classifier('Mouse_Classifier',true);
            self.window = window;
            self.StimLoc = StimLoc;
        end
        %------------------------------------------------------------------
        
        %------------------------------------------------------------------
        % Main Methods:
        function y = classifyTrial(self,~)
        %CLASSIFYTRIAL simply returns the selected target
            y = self.selected_target;
        end
        
        function decode_mouse_target(self)
        %DECODE_MOUSE_TARGET decodes the speller target based on the x,y
        %position of the mouse during a button click
            [x, y, buttons] = GetMouse(self.window);
            if(any(buttons))
                % determine which stimulus is selected
                for i=1:length(self.StimLoc)
                    if(IsInRect(x,y,self.StimLoc{i}))
                        self.selected_target = i;
                        break;
                    end
                end
            end   
        end
        %------------------------------------------------------------------
    end
    
end