function coords_xy = fx_count_cones(img, n_neighbors)
% img: the image to be analyzed, must be MxNx1 uint8
% n_neighbors: 4 or 8, 4 is usually sufficient and fast
%
% Credits:
% The core algorithm is from Kaccie Li & Austin Roorda
% [1] Li KY, Roorda A. Automated identification of cone photoreceptors in 
%   adaptive optics retinal images. J Opt Soc Am A Opt Image Sci Vis. 
%   2007;24(5):1358-63. doi: https://doi.org/10.1364/JOSAA.24.001358; 
%   PMCID: PMID: 17429481.
%
% It was adapted for use in Joe Carroll's lab by Robert Cooper
% [2] Cooper RF, Wilk MA, Tarima S, Carroll J. Evaluating descriptive 
%   metrics of the human cone mosaic. Invest Ophthalmol Vis Sci. 
%   2016;57(7):2992-3001. doi: 10.1167/iovs.16-19072; PMCID: PMC4898203.
%
% I've stripped the UI parts and it's now just the original first-pass of
% the Li and Roorda algorithm, Rob Cooper's faster nearest-neighbor
% distance based re-evaluation of the threshold, then a bit of trimming
% along the edges.
% [3] Salmon, AE, et al., Carroll, J. AO-PIPE (TBD)

%% Constants
% RMF = 291; % (retinal magnification factor) µm/degree (Emsley 1953 Visual Optics)
% AXIAL_LENGTH = 24; % mm, average for a human eye

%% Optional Inputs
% if exist('axiallength', 'var') == 0 || isempty(axiallength)
%     axiallength = 24; % Can always adjust the density values later
% end
if exist('n_neighbors', 'var') == 0 || isempty(n_neighbors)
    % Should use an input parser, only 4 & 8 are allowed
    n_neighbors = 4;
end


%% Image Scale
% pixelsperdegree = ppd;
% micronsperdegree = (RMF*axiallength)/AXIAL_LENGTH;
% micronsperpixel = 1 / (pixelsperdegree / micronsperdegree);

%% Verifying image format
%  Converting color 2 grayscale if color image: modification - ht
if(ndims(img) > 2) %#ok<ISMAT>
    img = rgb2gray(img);
end

%% Get dimensions
% [imsizey, imsizex] = size(img);
% areamm = ((imsizex*imsizey*micronsperpixel*micronsperpixel)./(1000.^2));

%% First pass to find cones and set filter
CutOffinit = 0.6;
Thrshld = 0;  % modification : HT
tic

%% Begin algorithm
img = double(img);
fc = imcomplement(img);
[M, N] = size(fc); 
% todo: why would this be different than the input image size?

% Finite impulse response (FIR) filter design
[f1, f2] = freqspace(15, 'meshgrid');
H = ones(15);
fr = sqrt(f1.^2 + f2.^2);
H(fr > CutOffinit) = 0;

window = fspecial('disk', 7);
% window = padarray(window./max(window(:)), [1+(496/2) 1+(496/2)] );
% window = fspecial('disk', 7);
window = window./max(window(:));
h = fwind2(H, window);
fc = imfilter(fc, h, 'replicate', 'same');
% fc = imfilter(fc, h, 0, 'same');

%% Morphological markers generation
LocalMins = imregionalmin(fc, n_neighbors);
se = strel('disk', 1, 0);

ConeMark = imdilate(LocalMins, se);

[L, numMark] = bwlabel(ConeMark);
stats = regionprops(L, 'centroid');
% X = zeros(numMark, 1);
% Y = X;
g = zeros(M, N);

for ii = 1:numMark
    loc = stats(ii).Centroid; %(x, y)
    loc = round(loc); %integral output
    if img(loc(2), loc(1)) > Thrshld
        g(loc(2), loc(1)) = 1;
    end
end

g = imbinarize(g);
[Y, X] = find(g == 1);

S = [X Y];

toc

%% Second-pass, refine threshold based on first estimate of cone frequency
% Quicker way to find N-N distance... RFC 06-20-2012
dist_between_pts=squareform(pdist(S)); % Measure the distance from each set of points to the other
max_ident=eye(length(dist_between_pts)).*max(dist_between_pts(:)); % Make diagonal not the minimum for any observation

[minval]=min(dist_between_pts+max_ident,[],2); % Find the minimum distance from one set of obs to another

nmmicronpix  = mean(minval); % Removed the code

conefreqpix = (1./nmmicronpix);
normpowerpix =.5;
CutOffnew = (conefreqpix.*1.2)/normpowerpix;

%Begin algorithm - second time through
ffc = imcomplement(img);
[MM, NN] = size(fc);

%FIR filter design - don't need to repeat setup steps as they are the exact
%same. Should save some exec time.
HH = ones(512, 512);
HH(fr > CutOffnew) = 0;
hh = fwind2(HH, window);
ffc = imfilter(ffc, hh, 'replicate', 'same');

%Morphological markers generation
LocalMinsfin = imregionalmin(ffc, 4);
ConeMarkfin = imdilate(LocalMinsfin, se);

[LL, numMarkfin] = bwlabel(ConeMarkfin);
statsfin = regionprops(LL, 'centroid');
% XX = zeros(numMarkfin, 1);
% YY = XX;
gg = zeros(MM, NN);

for jj = 1:numMarkfin
    loc = statsfin(jj).Centroid; %(x, y)
    loc = round(loc); %integral output
    if img(loc(2), loc(1)) > Thrshld
        gg(loc(2), loc(1)) = 1;
    end
end

gg = imbinarize(gg);
[YY, XX] = find(gg == 1);

% SS = [XX YY];

%% Get user input
% Removed for use with this program. -AES
% Quicker way to find N-N distance... RFC 06-20-2012
% dist_between_pts=squareform(pdist(SS)); % Measure the distance from each set of points to the other
% max_ident=eye(length(dist_between_pts)).*max(dist_between_pts(:)); % Make diagonal not the minimum for any observation
% [minval, minind]=min(dist_between_pts+max_ident,[],2); % Find the minimum distance from one set of obs to another
% nnmicronfinal = mean(minval.*micronsperpixel);

% Clip edge cones to reduce artifacting
clipped_coords=coordclip_npoly([YY XX],[2 max(YY)-1],[2 max(XX)-1]);
coords_xy = flip(clipped_coords, 2);

% % Calc this after clipping, or you will have huge gaps between manual and
% % auto.
% numConesAuto = length(clipped_coords);
% ConeDensityAuto = numConesAuto/areamm; 
% 
% % Return list of coordinates from add/remove program
% manual_mod_cones=cone_add_remove(uint8(img),clipped_coords*[0 1;1 0],'var');
% 
% 
% if (length(manual_mod_cones)==1) && manual_mod_cones==0
%     close all;
%     error('***** User exited program! *****');
%     
% end
% imsize = size(img);
% % Clip again so that there isnt any edge-added cones, even if the
% % user added them...
% manual_mod_cones=coordclip_npoly(manual_mod_cones,[2 max(XX)-1],[2 max(YY)-1]);
% 
% coneX = manual_mod_cones(:,1); 
% coneY = manual_mod_cones(:,2);
% numConesMan = length(manual_mod_cones); 
% 
% 
% ConeDensityMan = numConesMan/areamm; %corrected to include manually selected cones (7/22, mws)
% fprintf('The total number of cones found (manual and auto) is %4.0f cells. \n',numConesMan);
% fprintf('The cone density with manually added cones is %9.2f cells/mm^2 . \n',ConeDensityMan);
% fprintf(' \n');
% fprintf('The total number of cones found (automated) is %4.0f cells. \n',numConesAuto);
% fprintf('The automated cone density is %9.2f cones/mm^2 .\n',ConeDensityAuto);
% fprintf(' \n');
% change=numConesMan-numConesAuto;
% % If positive, that means that globally, the user added cells
% if change>=0
%     fprintf('The user manually added %3.0f cells. \n',change);
%     changetest='added';
% elseif change<0
%     fprintf('The user manually removed %3.0f cells. \n',abs(change));
%     changetest='removed';
% end
% 
% 
% 
% 
% %RFC 2011- Outputs displayed data to file
% statout=[axiallength pixelsperdegree numConesMan ConeDensityAuto numConesAuto ConeDensityMan change];
% statoutfname=fullfile(outpath,[getparent(pname,'short') '_density_info.csv']);
% 
% if exist(statoutfname,'file')
% 
%     fid=fopen(statoutfname,'a');
%     fprintf(fid,['"' fname '","Auto + Manual",']);% 1st/2nd column- filename/Detection Type
%     fclose(fid);
%     dlmwrite(statoutfname,statout,'-append'); % 2-6 columns- data
% 
% 
% 
% else
%     fid=fopen(statoutfname,'w');
%     % Create header
%     fprintf(fid,['"Filename","Detection Type","Axial Length","Pixels per Degree","Total Number of Cones","Auto Only Cone Density",'...
%                 '"Number of Auto Cones","Auto+Manual Cone Density","Number of Manually ' changetest ' Cones",\n']);
%     fprintf(fid,['"' fname '","Auto + Manual",']); % 1st/2nd column- filename/Detection Type
% 
%     dlmwrite(statoutfname,statout,'-append'); % 2-6 columns- data
% 
% 
%     fclose(fid);
% end
% 
% 
% dataforfile = [coneX coneY];
% 
% 
% dlmwrite(fullfile(outpath, [fname(1:end-4) '_coords.txt']),dataforfile,'delimiter','\t');


end

