function [outputData] = changeFs(data,newFs,originalFs)
%
% Downsample data to desired sampling rate. Can accomodate fractional
% originalFs
%
% Input parameters:
% data = channels x samples
% newFs = desired sampling rate, in Hz
% originalFs = desired sampling rate, in Hz
%
% Uses MATLAB functions rat and resample
%%
% If only 1 channel, want channel x samples
if iscolumn(data)
    data = data';
end

[N,D] = rat(originalFs/newFs);
temp = resample(data',D,N);

outputData = temp';
end