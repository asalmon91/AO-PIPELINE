function angles = getAngles(vid_num, montages)
%getAngles gets the angle of the vector between images that are supposed to
%connect but don't

angles = [];
for ii=1:numel(montages)
    idx = find(strcmp({montages(ii).images.num}, vid_num));
    if ~isempty(idx)
        angles = zeros(size(montages(ii).images(idx).neighbor));
        for jj=1:numel(montages(ii).images(idx).neighbor)
            angles(jj) = montages(ii).images(idx).neighbor(jj).angle;
        end
        break;
    end
end

for ii=1:numel(montages)
    for jj=1:numel(montages(ii).images)
        for kk=1:numel(montages(ii).images(jj).neighbor)
            if strcmp(montages(ii).images(jj).neighbor(kk).num, vid_num)
                angle = montages(ii).images(jj).neighbor(kk).angle;
                angle = angle + 180;
                if angle >= 360
                    angle = angle - 360;
                end
                angles = [angles; angle]; %#ok<AGROW>
            end
        end
    end
end

angles = unique(angles);

end

