function fn_write_AVI(ffname,mat3d,fr,wb,lag)
%fn_write_AVI Writes a 3d matrix as an AVI

vw = VideoWriter(ffname, 'grayscale avi');
vw.FrameRate = fr;

if exist('wb', 'var') ~= 0 && ~isempty(wb)
    waitbar(0, wb, 'Writing to AVI');
end
open(vw);
try
    for ii=1:size(mat3d,3)
        writeVideo(vw, mat3d(:,:,ii));
        
        if exist('wb', 'var') ~= 0 && ~isempty(wb)
        	waitbar(ii/size(mat3d,3), wb);
        end
        
        if exist('lag', 'var') ~= 0 && ~isempty(lag)
            if lag == -1 && ii==1
                pause();
            else
                pause(lag);
            end
        end
    end
catch
    close(vw);
end
close(vw);

end

