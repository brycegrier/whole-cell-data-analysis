function [organizedData, rawDataMatrix, rawDataTable, averageTrace] = exportData(varargin)

    % There are 4 optional arguments for this function
    %   numberOfEvents - how many events are exported
    %       default value = 200
    %       accepted values = >1
    %   exportedGroup - which group is exported
    %       default value = 'amplitude'
    %       accepted values = {'full', 'amplitude'}
    %       'full' = N events from the full event group are exported
    %       'amplitude' = N events from the amplitude group are exported
    %   frequencyCalculation - how frequency is calculated
    %       default value = 'all'
    %       accepted values = {'all','limited'}
    %       'all' = frequency is calculated from all selected events
    %       'limited' = frequency is calculated from the first N exported
    %                   events
    %   output - where variables are saved
    %       default value = 0
    %       accepted values = [0, 1]
    %       0 = output variables are only assigned in the workspace from
    %           which 'exportData' is called. this is useful for exporting
    %           data by hand
    %       1 = assign output variables to base workspace (mostly useful
    %           for auto-export at the end of analysis)
    % 
    %   examples:
    %   [organizedData, rawDataMatrix, rawDataTable, averageTrace] = exportData('exportedGroup','full','frequencyCalculation','all');
    %   [organizedData, rawDataMatrix, rawDataTable, averageTrace] = exportData('numberOfEvents',300,'frequencyCalculation','limited');
    %   [organizedData, rawDataMatrix, rawDataTable, averageTrace] = exportData('exportedGroup','ampltude','output',1);

    warning('off','MATLAB:load:variableNotFound');

    p = inputParser;
    addOptional(p,'output',false,@islogical);
    addOptional(p,'exportedGroup','amplitude',@ischar);
    addOptional(p,'frequencyCalculation','all',@ischar);
    addOptional(p,'numberOfEvents',200,@isnumeric);
    parse(p,varargin{:});
    output = p.Results.output;
    groupChoice = validatestring(p.Results.exportedGroup,["full", "amplitude"]);
    freqChoice = validatestring(p.Results.frequencyCalculation,["all", "limited"]);
    numEvents = p.Results.numberOfEvents;
    
    organizedData = struct();
    rawDataMatrix = [];
    rawDataTable = table();
    averageTrace = [];
    
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
      
    rootDirFolders = dir;
    foldersLogical = [rootDirFolders.isdir] == 1;
    rootDirFolders = rootDirFolders(foldersLogical);
    
    for folder = 3:size(rootDirFolders)
        neededVars = {'selectedEvents'; 'averageTrace'; 'averageTraceTau';...
                'averageTraceRsq'; 'averageTraceRiseTime'; 'averageTraceRiseSlope';...
                'allTraces'};
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
            loadedVars = load(filename.name, 'selectedEvents', 'averageTrace', 'averageTraceTau',...
                'averageTraceRsq','averageTraceRiseTime','averageTraceRiseSlope','allTraces');
        catch
            cd ..;
            continue;
        end
        loadedVars = fieldnames(loadedVars);
        missingVars = setdiff(neededVars,loadedVars);
        for i = 1:length(missingVars)
            feval(@()assignin('caller',missingVars{i},[]));
        end
        if sum(~isnan(selectedEvents)) == 0
            cd ..;
            continue;
        end
        selectedEvents = selectedEvents(~isnan(selectedEvents(:,eventTimeCol)),:);
        selectedEvents = abs(selectedEvents);
        
        switch groupChoice
            case {'full'}
                chosenGroupCol = fullEventLogicalCol;
            case {'amplitude'}
                chosenGroupCol = amplitudeLogicalCol;
        end
        if nansum(selectedEvents(:,chosenGroupCol)) < numEvents
            alert = sprintf('%s%s%s','Too few events in "', pwd,'". Experiment skipped.');
            matError = errordlg(alert);
            uiwait(matError);
            cd ..;
            continue;
        end
        while nansum(selectedEvents(:,chosenGroupCol)) > numEvents
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
        if strcmp(freqChoice,'limited')
            selectedEvents(numEvents:end,16) = nan; %BG 24Jan21 -- makes it so IMI is calculated from first (numEvents) events only
            organizedData(folder-2).frequency =...
                (length(selectedEvents)*1000)/...
                (((selectedEvents(numEvents,eventTimeCol)-selectedEvents(1,eventTimeCol))/...
                samplesPerMilliSecond));
        end
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
    else
        return;
    end
    if exportAverageTrace && isfield(organizedData,'averageTrace')
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
    
    warning('on','MATLAB:load:variableNotFound');
end