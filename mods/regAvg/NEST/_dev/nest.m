function [lps, thr, candidate_ncc_thr_lut] = nest(img, ncols, ss, wb)
%nest NCC ESTimation for Demotion
% "Ambiguity v. strip size"

%% Constants/Defaults
if exist('ncols', 'var') == 0 || isempty(ncols)
    ncols = floor(size(img,1)/4); % # columns to ignore in NCC
end

%% Set up candidate strip sizes if not given
if exist('ss', 'var') == 0 || isempty(ss)
    n_candidates = 15;
    ss = round(5*exp(.25*(1:n_candidates)));
else
    n_candidates = numel(ss);
end
    
%% Measurement arrays
ncc_ss = cell(n_candidates, 1);
for ii=1:n_candidates
    % ncc rows to ignore
    nrows = floor(ss(ii)/2);
    
    % Choose template strip based on minimum entropy
    [entropies, start_indices] = stripEntropy(img, ss(ii));
    ub_t = start_indices(entropies == min(entropies));
    if numel(ub_t) > 1
        ub_t = ub_t(1);
    end
    lb_t = ub_t + ss(ii) -1;
    t_strip = img(ub_t:lb_t, :);
    
    % vectors of sample strips
    ub_above = ub_t + ss(ii) : ss(ii) : size(img,1);
    ub_below = flip(ub_t - ss(ii) : -ss(ii) : 1);
    ub_s = [ub_below, ub_above];
    lb_s = ub_s + ss(ii) - 1;
    % Check for out-of-bounds
    oob = lb_s > size(img,1); 
    ub_s(oob) = [];
    lb_s(oob) = [];
    
    % Construct s_strips array
    s_strips = zeros(ss(ii), size(img, 2), numel(ub_s), class(img));
    for jj=1:numel(ub_s)
        % Sample Strip
        s_strips(:,:,jj) = img(ub_s(jj):lb_s(jj), :);
    end
    
    % Batch get max(ncc), optimized to avoid redundant fft's
    ncc_ss{ii} = getNCC_nest(t_strip, s_strips, ncols, nrows);
    
    % Waitbar
    if exist('wb', 'var') ~= 0 && ~isempty(wb)
        waitbar(ii/n_candidates, wb, sprintf('Testing ss=%i', ss(ii)));
    else
        fprintf('Testing ss=%i\n', ss(ii))
    end
end

%% Remove any empty iterations (sometimes largest ss doesn't fit)
empty_ss = cellfun(@isempty, ncc_ss);
ncc_ss(empty_ss)    = [];
ss(empty_ss)        = [];
n_candidates = numel(ss);

%% Compile results into one vector and corresponding ss
n_iter = cellfun(@numel, ncc_ss);
n_nccs = sum(n_iter);
all_nccs = zeros(n_nccs, 1);
all_ss = all_nccs;
for ii=1:n_candidates
    if ii==1
        indices = 1:n_iter(1); 
    else
        indices = sum(n_iter(1:ii-1)) +1 : sum(n_iter(1:ii-1)) + n_iter(ii);
    end
	all_nccs(indices) = ncc_ss{ii};
    all_ss(indices) = repmat(ss(ii), n_iter(ii), 1);
end

%% Parabolic increase in cost scaled by range of autocorrelation
autocorr = getACC(img);
max_corr_diff = range(autocorr(:));
m = max_corr_diff/((size(img,1)/2)^2);
cost_fx = @(x) m.*(x.^2);

%% Apply Cost function
% obj_fx = max_nccs + cost_fx(ss);
obj_fx = all_nccs + cost_fx(all_ss);

% Custom fit, ambiguity tends to follow a sqrt(s) fx and the amount of
% potential motion error we introduce by increasing strip size increases
% with the square of strip size (Cost fx). So we fit to f(s)=as^-.5 + bs^2
ft = fittype('(a*(x^-.5)+c) + (b*x^2+d)', ...
    'independent', 'x', 'dependent', 'y' );
% ft = fittype( '(a*x^-.5+c) + (b*x+d)', ...
%     'independent', 'x', 'dependent', 'y' );
opts = fitoptions( 'Method', 'NonlinearLeastSquares' );
opts.Display = 'Off';
opts.StartPoint = [0, 0.5, 0, 0.5];
[fx_sqrt_sqr, ~] = fit( all_ss, obj_fx, ft, opts);
% Sample every ss
fx = min(ss):max(ss);
fy = fx_sqrt_sqr(fx);

%% Find strip size that minimizes objective function
lps = fx(fy==min(fy));

%% Find minimum uniqueness
max_nccs = zeros(size(ss));
for ii=1:n_candidates
    max_nccs(ii) = max(all_nccs(all_ss == ss(ii)));
end

%% Determine NCC threshold
interp_max_ncc = interp1(ss, max_nccs, fx, 'linear');
thr = interp_max_ncc(fx==lps);
if round(thr, 2) == 1
    thr = 0.99;
end

% Output this in case the lps estimate doesn't work out
candidate_ncc_thr_lut = [fx; interp_max_ncc];

end

