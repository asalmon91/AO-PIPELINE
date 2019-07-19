function data = getInt(imgs, data, sdx)
%getInt rejects frames with low intensity (mean-x*SD) and fully 
% saturated frames % (sometimes happens with split frames)
% sdx is a standard deviation multiplier

%% Get mean intensity
rem_ids = [data(~[data.rej]).id]';
imgs = imgs(:,:,rem_ids);

mInt = mean(squeeze(mean(imgs,1)),1)';

%% Find dim frames
mIntNorm = (mInt - mean(mInt))./std(mInt);
badFrames = rem_ids(mIntNorm < -sdx | mInt == 255);

data = rejectFrames(data, badFrames, mfilename);

end