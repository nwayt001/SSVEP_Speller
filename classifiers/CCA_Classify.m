%% CCA classification function
function [y] = CCA_Classify(X,yRef)
% X is a single SSVEP trial to be classified
%   [ timepoints x channels ] 
% yRef are the cca templates

% compute CCA for each frequency class
for ii = 1:size(yRef,1)
%     display(size(X));
%     tmp = squeeze(yRef(ii,1:size(X,1),:));
%     display(size(tmp));
    [~,~,r(:,ii)] = canoncorr(X,squeeze(yRef(ii,1:size(X,1),:)));
end
[~, y]=max(r(1,:));  % classify
end