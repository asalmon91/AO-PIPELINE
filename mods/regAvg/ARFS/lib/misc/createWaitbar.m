function wb = createWaitbar()
%createWaitbar creates a waitbar with no interpreter

wb = waitbar(0, 'Initializing waitbar...');
wb.Children.Title.Interpreter = 'none';

end

