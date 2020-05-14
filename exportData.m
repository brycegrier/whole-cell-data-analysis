function exportData(varargin)

    p = inputParser;
    addOptional(p,'file','',@ischar);
    parse(p,varargin{:});
        
    file = p.Results.file;
    samplesPerMilliSecond = 10;
    fullEventLogicalCol = 1;     % logical value for inclusion of mini in full event measurement    
%     amplitudeLogicalCol = 2;        % logical value for inclusion of mini in amplitude measurement
%     frequencyLogicalCol = 3;        % logical value for inclusion of mini in frequency measurement
    amplitudeValueCol = 4;          % measurement of mini amplitude 
    risetime1090ValueCol = 5;       % measurement of mini 10-90 rise time
    riseslope1090ValueCol = 6;      % measurement of mini 10-90 slope
%     rise50TimeCol = 7;              % sample point at which mini rise 50 occurs
%     decay50TimeCol = 8;             % sample point at which mini decay 50 occurs
    halfWidthValueCol = 9;         % measurement of mini half width
    decayValueCol = 10;
    aucValueCol = 11;               % measurement of area to .5 of peak value
    eventTimeCol = 12;   
    averageTraceLogicalCol = 13;
    
    if ~strcmp(file,'')
        fileSpec = strcat('*',file,'*.mat');
    else
        fileSpec = '*.mat';
    end
    rootDirFolders = dir;
    foldersLogical = [rootDirFolders.isdir] == 1;
    rootDirFolders = rootDirFolders(foldersLogical);
    dataStruct = struct();
    dataMat = [];
    for folder = 3:size(rootDirFolders)
        nextDir = rootDirFolders(folder).name;
        if ~isfolder(nextDir)
            continue;
        end
        cd(nextDir);
        filename = dir(fileSpec);
        try
            load(filename.name, 'selectedEvents', 'averageTrace', 'averageTraceTau','averageTraceRsq','allTraces');
        catch
            cd ..;
            continue;
        end
        selectedEvents = selectedEvents(~isnan(selectedEvents(:,eventTimeCol)),:);
        selectedEvents = abs(selectedEvents);
        while nansum(selectedEvents(:,fullEventLogicalCol)) > 200
            selectedEvents = selectedEvents(1:end-1,:);
        end
        allTraces = allTraces(:,selectedEvents(:,averageTraceLogicalCol) == 1);
        cellName = convertCharsToStrings(split(filename.name,"."));
        cellName = cellName(1);
        dataStruct(folder-2).cell = cellName;
        dataStruct(folder-2).frequency = (length(selectedEvents)*1000)/(selectedEvents(end,eventTimeCol)/samplesPerMilliSecond-selectedEvents(1,eventTimeCol)/samplesPerMilliSecond);
        dataStruct(folder-2).amplitude = nanmean(selectedEvents(:,amplitudeValueCol));
        dataStruct(folder-2).rise1090 = nanmean(selectedEvents(:,risetime1090ValueCol));
        dataStruct(folder-2).halfwidth = nanmean(selectedEvents(:,halfWidthValueCol));
        dataStruct(folder-2).slope1090 = nanmean(selectedEvents(:,riseslope1090ValueCol));        
        dataStruct(folder-2).area = nanmean(selectedEvents(:,aucValueCol));
        dataStruct(folder-2).decayTime = nanmean(selectedEvents(:,decayValueCol));
        dataStruct(folder-2).decayTau = averageTraceTau;   
        dataStruct(folder-2).Rsq = averageTraceRsq;  
        dataStruct(folder-2).averageTrace = averageTrace;
        dataStruct(folder-2).allTraces = allTraces;
        tempIMI = [];
        tempIMI(1) = nan;
        for i = 2:size(selectedEvents,1)
            tempIMI(i) = (selectedEvents(i,eventTimeCol)-selectedEvents(i-1,eventTimeCol))/10;
        end
        tempIMI = tempIMI';
        selectedEvents(:,16) = tempIMI;
        dataMat = [dataMat; selectedEvents];
        cd ..;
    end
    averageTrace = mean([dataStruct.averageTrace],2);
    assignin('base','averageTrace',averageTrace);
    assignin('base','dataStruct',dataStruct);
    assignin('base','dataMat',dataMat);
end