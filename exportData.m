function [organizedData, rawDataMatrix, rawDataTable, averageTrace] = exportData(varargin)

    p = inputParser;
%     addOptional(p,'file','*.mat',@ischar);
    addOptional(p,'output',false,@islogical);
    parse(p,varargin{:});
%     file = p.Results.file;
    output = p.Results.output;
    
    dataTableColumnNames = {'FullMeasure','AmplitudeMeasure','FrequencyMeasure',...
    'Amplitude(pA)','RiseTime(ms)','RiseSlope(pA/ms)','Rise50(SamplePoint)',...
    'Decay50(SamplePoint)','HalfWidth(ms)','DecayTime(ms)','Area(fC)',...
    'Threshold(SamplePoint)','AverageTraceMeasure','unused1','unused2',...
    'Interval','unused3','unused4','unused5','unused6'};

    samplesPerMilliSecond = 10;
    fullEventLogicalCol = 1;     % logical value for inclusion of mini in full event measurement    
    amplitudeLogicalCol = 2;        % logical value for inclusion of mini in amplitude measurement
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
      
%     if ~strcmp(file,'')
%         fileSpec = strcat('*',file,'*.mat');
%     else
%         fileSpec = '*.mat';
%     end

    rootDirFolders = dir;
    foldersLogical = [rootDirFolders.isdir] == 1;
    rootDirFolders = rootDirFolders(foldersLogical);
    organizedData = struct();
    rawDataMatrix = [];
    for folder = 3:size(rootDirFolders)
        averageTraceTau = [];
        averageTraceRsq = [];
        averageTraceRiseSlope = [];
        averageTraceRiseTime = [];
        nextDir = rootDirFolders(folder).name;
        if ~isfolder(nextDir)
            continue;
        end
        cd(nextDir);
        filename = dir('*.mat');
        if size(filename,1) > 1
            alert = sprintf('%s%s%s','Multiple save files in "', pwd,'". Experiment skipped.');
            matError = errordlg(alert);
            uiwait(matError);
            cd ..;
            continue;
        end
        try
            load(filename.name, 'selectedEvents', 'averageTrace', 'averageTraceTau',...
                'averageTraceRsq','averageTraceRiseTime','averageTraceRiseSlope','allTraces');
        catch
            cd ..;
            continue;
        end
        if sum(~isnan(selectedEvents)) == 0
            cd ..;
            continue;
        end
        selectedEvents = selectedEvents(~isnan(selectedEvents(:,eventTimeCol)),:);
        selectedEvents = abs(selectedEvents);
        while nansum(selectedEvents(:,amplitudeLogicalCol)) > 200
            selectedEvents = selectedEvents(1:end-1,:);
        end
        allTraces = allTraces(:,selectedEvents(:,averageTraceLogicalCol) == 1);
        cellName = convertCharsToStrings(split(filename.name,"."));
        cellName = cellName(1);
        organizedData(folder-2).cell = cellName;
        organizedData(folder-2).events = selectedEvents;
        organizedData(folder-2).frequency = (length(selectedEvents)*1000)/(selectedEvents(end,eventTimeCol)/samplesPerMilliSecond-selectedEvents(1,eventTimeCol)/samplesPerMilliSecond);
        organizedData(folder-2).amplitude = nanmean(selectedEvents(:,amplitudeValueCol));
        organizedData(folder-2).rise = nanmean(selectedEvents(:,risetime1090ValueCol));
        organizedData(folder-2).halfwidth = nanmean(selectedEvents(:,halfWidthValueCol));
        organizedData(folder-2).slope = nanmean(selectedEvents(:,riseslope1090ValueCol));        
        organizedData(folder-2).area = nanmean(selectedEvents(:,aucValueCol));
        organizedData(folder-2).decay = nanmean(selectedEvents(:,decayValueCol));
        organizedData(folder-2).averageTraceRiseTime = averageTraceRiseTime;
        organizedData(folder-2).averageTraceRiseSlope = averageTraceRiseSlope;
        organizedData(folder-2).averageTraceDecayTau = averageTraceTau;   
        organizedData(folder-2).averageTraceDecayFitRsq = averageTraceRsq;  
        organizedData(folder-2).averageTrace = averageTrace;
        organizedData(folder-2).allTraces = allTraces;
        tempIMI = [];
        tempIMI(1) = nan;
        for i = 2:size(selectedEvents,1)
            tempIMI(i) = (selectedEvents(i,eventTimeCol)-selectedEvents(i-1,eventTimeCol))/10;
        end
        tempIMI = tempIMI';
        selectedEvents(:,16) = tempIMI;
%         selectedEvents(200:end,16) = nan; %BG 24Jan21 -- makes it so IMI is calculated from first 200 events only
        rawDataMatrix = [rawDataMatrix; selectedEvents];
        cd ..;
    end
    exportAverageTrace = 1;
    for i = 1:size(organizedData,2)-1
        if length(organizedData(i).averageTrace) ~= length(organizedData(i+1).averageTrace)
            if isempty(organizedData(i).averageTrace) || isempty(organizedData(i+1).averageTrace)
                continue;
            else
                disp('Average traces are different lengths. Please fix and re-export.');
                exportAverageTrace = 0;
                break;
            end
        end

    end
    if ~isempty(rawDataMatrix)
        rawDataTable = array2table(rawDataMatrix);
        rawDataTable.Properties.VariableNames = dataTableColumnNames;
    end
    if exportAverageTrace == 1
        averageTrace = mean([organizedData.averageTrace],2);
        if output == 1
            assignin('base','averageTrace',averageTrace);
        end
    end
    if output == 1
        assignin('base','organizedData',organizedData);
        assignin('base','rawDataMatrix',rawDataMatrix);
        assignin('base','rawDataTable',rawDataTable);
    end
end