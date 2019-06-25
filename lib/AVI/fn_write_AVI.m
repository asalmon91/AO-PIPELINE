function fn_write_AVI(ffname,mat3d,fr,wb)
%fn_write_AVI Writes a 3d matrix as an AVI

vw = VideoWriter(ffname, 'grayscale avi');
vw.FrameRate = fr;
waitbar(0, wb, 'Writing to AVI');
open(vw);
try
    for ii=1:size(mat3d,3)
        writeVideo(vw, mat3d(:,:,ii));
        
        waitbar(ii/size(mat3d,3), wb);
    end
catch
    close(vw);
end
close(vw);

end

