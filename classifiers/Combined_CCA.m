classdef Combined_CCA < SSVEP_classifier
    properties
        trainTemplates
    end
    
    methods
        %------------------------------------------------------------------
        % Class constructor:
        function self = Combined_CCA(harmonics,trialLength,Fs,freqs,debugMode,filename)
            if(isempty(filename))
                filename = 'DummyModels';
            end
            self@SSVEP_classifier('CCA',harmonics,trialLength,Fs,freqs,debugMode);
            self.trainTemplates = load(filename);
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
        [~,y] = max(R);
        end
        
        %------------------------------------------------------------------
    end
end