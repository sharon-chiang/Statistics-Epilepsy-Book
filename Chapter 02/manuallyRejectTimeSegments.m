function manuallyRejectTimeSegments(data,Fs)
%
% Highlight data segments with bad data and return the indices of these periods
%
% Input parameters:
% data = channels x samples
% Fs = data sampling rate, in Hz
%
% Note: This function requires EEGLAB functions. 'tempMarkedRejection' in main workspace
% will have rejected data segment information
%%

% If only 1 channel, want channel x samples
if iscolumn(data)
    data = data';
end

rejCommand = [...
    'tempMarkedRejection = [];'...
    'if ~isempty(TMPREJ),'...
    'tempMarkedRejection  = eegplot2event(TMPREJ, -1);'...
    'end;'...
    ];

TMPREJ = [];
tempMarkedRejection = [];
eegplot(data,'srate',Fs,'winlength',15,'wincolor',[1 0 0],'command',rejCommand,...
    'title','Select data segments to remove');
uiwait

end