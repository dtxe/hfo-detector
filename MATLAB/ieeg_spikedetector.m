function [out, spikes] = ieeg_spikedetector(data, varargin)

ip = inputParser;
addParameter(ip, 'filt', [25 80]);
addParameter(ip, 'zthresh', 3);
addParameter(ip, 'mindur', 0.001);
addParameter(ip, 'channel', 1);
% addParameter(ip, 'downsample', 1);   % no need to downsample for this code.

parse(ip, varargin{:})

mindur_sample = ceil(ip.Results.mindur * data.fsample);

%% processing
cfg = [];
cfg.bpfreq = ip.Results.filt;
cfg.bpfilter = 'yes';
cfg.channel = ip.Results.channel;

data_pp = ft_preprocessing(cfg, data);


% compute envelopes
ts_pp = abs(hilbert(abs(data_pp.trial{1}(1,:))));
ts_uf = abs(hilbert(data.trial{1}(ip.Results.channel,:)));

ts_pp = zscore(ts_pp);
ts_uf = zscore(ts_uf);

%% run algo
% get segments of suprathreshold filtered signal
rp_pp = regionprops(ts_pp >= ip.Results.zthresh);


nelem = numel(rp_pp);
isspike = true(size(rp_pp,1), 1);
for kk = 1:length(rp_pp)
  % check whether it exceeds minimum duration
  if rp_pp(kk).Area < mindur_sample
    isspike(kk) = false;
    continue
  end
  
  % check whether there is a corresponding increase in broadband env
  if mean(ts_uf(round(rp_pp(kk).BoundingBox(1)) + (1:rp_pp(kk).BoundingBox(3)))) < ip.Results.zthresh
    isspike(kk) = false;
    continue
  end
end

if nelem == 0 || ~any(isspike)
  out = [];
else
  out = {rp_pp(isspike).Centroid;};
  out = cellfun(@(x) round(x(1)), out);  % * ip.Results.downsample;
end
spikes = rp_pp(isspike);

