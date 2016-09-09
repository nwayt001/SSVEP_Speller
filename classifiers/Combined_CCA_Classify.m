%% Modified CCA based on PNAS paper 
function [y] = Combined_CCA_Classify(X,yRef,Xtrain)
% INPUT:
% X is [ timepoints x channels ] 
% Xtrain ix [timepoints x channels x class]
% yRef is [class x timepoints x harmonics]

% OUTPUT:
% Class y

% Wx1 = CCA between X and Y
% Wx2 = CCA between X and X^
% Wx3 = CCA between X^ and Y

% for each class compute 5 correlations
r = zeros(1,5);
R = zeros(1,size(yRef,1));
for ii = 1:size(yRef,1)
    
    % compute rk(1) - CCA between X and Y
    [Wx1,~,tmp] = canoncorr(X,squeeze(yRef(ii,1:size(X,1),:)));
    r(1) = tmp(1);
    
    % compute rk(2) - CCA between X and X^ and corr X and X^
    [Wx2,~] = canoncorr(X,Xtrain(1:size(X,1),:,ii));
    r(2) = corr(X*Wx2(:,1),Xtrain(1:size(X,1),:,ii)*Wx2(:,1));
    
    % compute rk(3) - CCA between X and Y and corr X and X^
    r(3) = corr(X*Wx1(:,1),Xtrain(1:size(X,1),:,ii)*Wx1(:,1));
       
    % compute rk(4) - CCA between X^ and Y and corr X and X^
    [Wx3,~] = canoncorr(Xtrain(1:size(X,1),:,ii),squeeze(yRef(ii,1:size(X,1),:)));
    r(4) = corr(X*Wx3(:,1),Xtrain(1:size(X,1),:,ii)*Wx3(:,1));
    
    % compute rk(5) - CCA between X and X^ and corr X^ and X^
    r(5) = corr(Xtrain(1:size(X,1),:,ii)*Wx2(:,1),Xtrain(1:size(X,1),:,ii)*Wx2(:,1));
    
    % aggergate the r's
    tmpSum=0;
    for i=1:5
        tmpSum = tmpSum + (sign(r(i)) * (r(i)^2));
    end
    R(ii) = tmpSum;
end
[~,y] = max(R);
end