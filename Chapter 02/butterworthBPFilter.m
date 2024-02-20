function [filtData] = butterworthBPFilter(data,passBand,order,Fs)
%
% Input parameters:
% data = channels x samples
% passBand = vector with passband frequencies, in Hz
% order = filter order
% Fs = data sampling rate, in Hz
%%
% If only 1 channel, want channel x samples
if iscolumn(data)
    data = data';
end

runOrder = order/2; % For bandpass designs, runOrder represents one-half the filter order

% Define filter parameters
Fc = passBand; % Desired passband frequency cutoffs
Fn = Fs/2; % Nyquist frequency
Wn = Fc/Fn; % Filter frequency constraints (expressed between 0 and 1, where 1 corresponds to Nyquist frequency)
[b1, a1] = butter(runOrder, Wn, 'bandpass');

% Run filter using MATLAB function filtfilt
for iChan = 1:size(data,1)
    filtData(iChan,:) = filtfilt(b1,a1,data(iChan,:));
end

end