function [filtData] = butterworthNotchFilter(data,notchFreq,order,Fs)
%
% Input parameters:
% data = channels x samples
% notchFreq = frequency for centering notch filter, in Hz
% order = filter order
% Fs = data sampling rate, in Hz
%%
% If only 1 channel, want channel x samples
if iscolumn(data)
    data = data';
end

runOrder = order/2; % because implementing bandpass filter for notch

% Define filter parameters
Fc = [notchFreq-2 notchFreq+2]; % Desired notch frequency to remove
Fn = Fs/2; % Nyquist frequency
Wn = Fc/Fn; % Filter frequency constraints (expressed between 0 and 1, where 1 corresponds to Nyquist frequency)
[b1, a1] = butter(runOrder, Wn, 'stop');

% Run notch filter using MATLAB function filtfilt
for iChan = 1:size(data,1)
    filtData(iChan,:) = filtfilt(b1,a1,data(iChan,:));
end

end