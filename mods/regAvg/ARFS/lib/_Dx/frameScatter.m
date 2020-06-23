function frameScatter(vid, frames)
%frameScatter Displays the motion tracking results

ht = size(vid,1);
wd = size(vid,2);

figure;
link_sort = sortLink_id_bySize(frames);
nsp = ceil(sqrt(numel(link_sort))); % number of subplots
for ii=1:numel(link_sort)
    subplot(nsp,nsp,ii);
    set(gca,'fontname','arial','fontsize',7,'tickdir','out',...
        'ydir','reverse','zdir','reverse')
    title(sprintf('Group %i',link_sort(ii)),...
        'FontName','Arial','FontSize',9);
    xlabel('x (px)','FontName','Arial','FontSize',9);
    ylabel('y (px)','FontName','Arial','FontSize',9);
    zlabel('Frame number','FontName','Arial','FontSize',9);
    hold on;
    
    clusters = sortClusterBySize(frames, link_sort(ii));
    colors = jet(numel(clusters));
    for jj=1:numel(clusters)
        ids = [frames(...
            [frames.link_id] == link_sort(ii) & ...
            [frames.cluster] == clusters(jj)).id];
        xy = getAllXY(frames(ids));
        
        % Plot frames
        for kk=1:size(xy,1)
            patch(...
                'xdata',[xy(kk,1), xy(kk,1)+wd-1, xy(kk,1)+wd-1, xy(kk,1)],...
                'ydata',[xy(kk,2), xy(kk,2), xy(kk,2)+ht-1, xy(kk,2)+ht-1],...
                'zdata',ids(kk).*ones(4,1),...
                'facecolor','none','edgecolor',colors(jj,:));
        end
    end
    hold off;
    axis tight equal;
    view([-45,15])
end

end

