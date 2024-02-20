close all
clear all
clc

% Load raw data from .edf file
[header, rawData] = edfread(fileName);

% Extract sampling rate from file header
Fs = header.frequency(1);

% Bandpass filtering [1 500] -- should remove large transient from stim onset and
% offset
filterOrder = 4;
passBand = [1 500];
disp('Bandpass filtering data: [1-500]Hz')
filtData = butterworthBPFilter(rawData,passBand,filterOrder,Fs);

% Notch filter
notchFreq = 60;
filterOrder = 4;
disp('60Hz (and harmonics) notch filtering')
while notchFreq < 500
    filtData = butterworthNotchFilter(filtData,notchFreq,filterOrder,Fs);
    notchFreq = notchFreq + 60; % get harmonics
end

% CAR across all channels
disp('CAR rereferencing')
reref = nanmean(filtData,1);
CAR_ECOG = bsxfun(@minus,filtData,reref);

% Manually select bad periods of data
removeOrReplace = 1; % 1 = replace bad data with NaNs; 2 = remove bad data
manuallyRejectTimeSegments(CAR_ECOG,Fs);
cleanedECOG = CAR_ECOG;

if ~exist('tempMarkedRejection','var')
    tempMarkedRejection = [];
end
if removeOrReplace == 1 % Replacing bad data with NaNs
    if ~isempty(tempMarkedRejection)
        for iRejection = 1:size(tempMarkedRejection,1)
            cleanedECOG(:,tempMarkedRejection(iRejection,3):tempMarkedRejection(iRejection,4)) = NaN;
        end
        rejectionTimes = sortrows(tempMarkedRejection);
    end

elseif removeOrReplace == 2 % Removing bad data -- time is no longer accurate
    % Need to sort rejectionTimes so they are early to late
    rejectionTimes = sortrows(tempMarkedRejection);

    if ~isempty(tempMarkedRejection)
        for iRejection = size(rejectionTimes,1):-1:1
            cleanedECOG(:,rejectionTimes(iRejection,3):rejectionTimes(iRejection,4)) = [];
        end
    end
end

% Downsample to 1000Hz
dsFs = 1000;
preprocessedECOG = changeFs(cleanedECOG,dsFs,Fs);