function [outputArg1,outputArg2] = getNextMontage(ld)
%UNTITLED4 Summary of this function goes here
%   Detailed explanation goes here

%% Default
montage_idx = [];
if ~isfield(ld.mon, 'imgs') || isempty(ld.mon.imgs)
    return;
end

%% Determine all images that haven't been matched
montage_idx = false(size(ld.mon.imgs));
for ii=1:numel(ld.mon.imgs)
    if isempty(ld.mon.imgs)
        
    else
        
        
        
    end
end



end

