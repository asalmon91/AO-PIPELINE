function runJsx(ps_path, jsx_ffname)
%runJsx opens the .jsx file (photoshop script) in photoshop

[jsx_success, stdout] = ...
    system(sprintf('"%s" "%s" &', ps_path, jsx_ffname));

end

