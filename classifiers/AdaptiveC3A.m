classdef AdaptiveC3A < SSVEP_classifier
    properties
        trainTemplates
        threshold = 1.15;
        alpha = 0.07;
    end
    
    methods
        %------------------------------------------------------------------
        % Class constructor:
        function self = AdaptiveC3A(harmonics,trialLength,Fs,freqs,debugMode,filename,sessionNum)
            self@SSVEP_classifier('CCA',harmonics,trialLength,Fs,freqs,debugMode);
            
            % if this is the first session, load base models, else load the
            % last session's models
            if(sessionNum==1)
                self.trainTemplates = load('data/ClassifierModels/BaseModels');
                self.trainTemplates = self.trainTemplates.trainTemplates;
                self.filename = filename;
            elseif(sessionNum>1)
                self.filename = filename;
                self.trainTemplates = load(self.filename);
                self.trainTemplates = self.trainTemplates.trainTemplates;
                trainTemplates = self.trainTemplates;
                save([self.filename '_' int2str(sessionNum)],'trainTemplates');
            else %this is a calibration session
                self.debugMode = true;
            end
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
        r = zeros(1,5);
        R = zeros(1,size(obj.yRef,1));
        for ii = 1:size(obj.yRef,1)
            
            % compute rk(1) - CCA between X and Y
            [Wx1,~,tmp] = canoncorr(X,squeeze(obj.yRef(ii,1:size(X,1),:)));
            r(1) = tmp(1);
            
            % compute rk(2) - CCA between X and X^ and corr X and X^
            [Wx2,~] = canoncorr(X,obj.trainTemplates(1:size(X,1),:,ii));
            r(2) = corr(X*Wx2(:,1),obj.trainTemplates(1:size(X,1),:,ii)*Wx2(:,1));
            
            % compute rk(3) - CCA between X and Y and corr X and X^
            r(3) = corr(X*Wx1(:,1),obj.trainTemplates(1:size(X,1),:,ii)*Wx1(:,1));
            
            % compute rk(4) - CCA between X^ and Y and corr X and X^
            [Wx3,~] = canoncorr(obj.trainTemplates(1:size(X,1),:,ii),squeeze(obj.yRef(ii,1:size(X,1),:)));
            r(4) = corr(X*Wx3(:,1),obj.trainTemplates(1:size(X,1),:,ii)*Wx3(:,1));
            
            % compute rk(5) - CCA between X and X^ and corr X^ and X^
            r(5) = corr(obj.trainTemplates(1:size(X,1),:,ii)*Wx2(:,1),obj.trainTemplates(1:size(X,1),:,ii)*Wx2(:,1));
            
            % aggergate the r's
            tmpSum=0;
            for i=1:5
                tmpSum = tmpSum + (sign(r(i)) * (r(i)^2));
            end
            R(ii) = tmpSum;
        end
        [B,y] = max(R);
        % BvSB metric (Best vs Second Best)
        R(y)=[];
        [SB,~] = max(R);
        BvSB = B/SB;

        % Adapt to trial if above threshold
        if(BvSB>=obj.threshold)
            obj.trainTemplates(:,:,y) = ((squeeze(obj.trainTemplates(:,:,y)).*(1-obj.alpha)) + (X.*obj.alpha));
        end
        end

        function terminate(obj)
            if(~obj.debugMode)
                % Save templates before closing
                trainTemplates = obj.trainTemplates;
                save(obj.filename,'trainTemplates');
            end
        end
        %------------------------------------------------------------------
        
        
    end
end