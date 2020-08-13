function [out, spindles] = ieeg_spindledetector(data, varargin)

ip = inputParser;
addParameter(ip, 'filt_low', [2 8]);
addParameter(ip, 'filt_spindle', [10 20]);
addParameter(ip, 'filt_high', [25 40]);
addParameter(ip, 'dur_min', 0.3);
addParameter(ip, 'dur_max', 3);
addParameter(ip, 'threshold', 0.1);
addParameter(ip, 'channel', 1);
addParameter(ip, 'downsample', 4);

parse(ip, varargin{:})

mindur_sample = ceil(ip.Results.dur_min * data.fsample);
maxdur_sample = ceil(ip.Results.dur_max * data.fsample);

%% processing
cfg = [];
cfg.method = 'wavelet';
cfg.channel = ip.Results.channel;
cfg.toi = data.time{1}(1:ip.Results.downsample:end);

cfg.foi = mean(ip.Results.filt_low);
cfg.width = 6*cfg.foi/diff(ip.Results.filt_low);
data_low = ft_freqanalysis(cfg, data);

cfg.foi = mean(ip.Results.filt_spindle);
cfg.width = 6*cfg.foi/diff(ip.Results.filt_spindle);
data_spindle = ft_freqanalysis(cfg, data);

cfg.foi = mean(ip.Results.filt_high);
cfg.width = 6*cfg.foi/diff(ip.Results.filt_high);
data_high = ft_freqanalysis(cfg, data);

ts_low = squeeze(data_low.powspctrm);
ts_spindle = squeeze(data_spindle.powspctrm);
ts_high = squeeze(data_high.powspctrm);


%% run algo
ratio = (ts_spindle - ts_low - ts_high)./(ts_spindle + ts_low + ts_high);

% get segments of suprathreshold filtered signal
rp_pp = regionprops(ratio >= ip.Results.threshold);

nelem = numel(rp_pp);
isspindle = true(size(rp_pp,1), 1);
for kk = 1:length(rp_pp)
  % check whether it passes duration criterion
  if rp_pp(kk).Area < mindur_sample || rp_pp(kk).Area > maxdur_sample
    isspindle(kk) = false;
    continue
  end
end

if nelem == 0 || ~any(isspindle)
  out = [];
else
  out = {rp_pp(isspindle).Centroid;};
  out = cellfun(@(x) round(x(1)), out) * ip.Results.downsample;
end
spindles = rp_pp(isspindle);

