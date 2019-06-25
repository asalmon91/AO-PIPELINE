function data = getInt(imgs, data)
%getInt rejects frames with low intensity (mean-3*stdev) and fully 
% saturated frames % (sometimes happens with split frames)

%% Get mean intensity
rem_ids = [data(~[data.rej]).id]';
imgs = imgs(:,:,rem_ids);

mInt = mean(squeeze(mean(imgs,1)),1)';

%% Find outliers
mIntNorm = (mInt - mean(mInt))./std(mInt);
badFrames = rem_ids(mIntNorm < -3 | mInt == 255);

data = rejectFrames(data, badFrames, mfilename);

end