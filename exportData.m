function [OrganizedData, RawDataMatrix_AllCells, RawDataTable_AllCells, AverageTrace_AllCells] = exportData(varargin)

    % There are 4 optional arguments for this function
    %   numberOfEvents - how many events are exported
    %       default value = 200
    %       accepted values = >1
    %   eventLimit - how many events are required from each cell
    %       default value = 'exactly'
    %       accepted values = {'exactly','all'}
    %       'exactly' = all cells must have exactly N events
    %       'all' = all events up to N events are exported
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
    %       NOTE: if eventLimit is set to 'all', and a cell has fewer than
    %             N events, frequency is calculated from all events
    %   riseLimits - the % limits on calculating the average trace rise time 
    %       default value = [10 90]
    %       accepted values = [n1 n2], where n1 < n2
    %   decayLimits - the $ limits on calculating the average trace decay 
    %       default value = [80 20]
    %       accepted values = [n1 n2], where n1 > n2
    % 
    %   examples:
    %   [organizedData, rawDataMatrix, rawDataTable, averageTrace] = exportData('exportedGroup','full','frequencyCalculation','all');
    %   [organizedData, rawDataMatrix, rawDataTable, averageTrace] = exportData('numberOfEvents',300,'frequencyCalculation','limited');
    %   [organizedData, rawDataMatrix, rawDataTable, averageTrace] = exportData('exportedGroup','ampltude',riseLimits,[35 85]);
    
    %% initialize variables
    
    % output variables
    OrganizedData = struct();
    RawDataMatrix_AllCells = [];
    RawDataTable_AllCells = table();
    dataTableColumnNames = {'FullMeasure','AmplitudeMeasure','FrequencyMeasure',...
    'AverageTraceMeasure','Amplitude(pA)','RiseTime(ms)','RiseSlope(pA/ms)',...
    'HalfWidth(ms)','DecayTime(ms)','Area(fC)','Time(SamplePoint)',...
    'Time(ms)','Interval(ms)'};
    averageTraceTau = [];
    averageTraceRiseTime = [];
    averageTraceRsq = [];
    averageTraceRiseSlope = [];
    rootDirFolders = dir;
    foldersLogical = [rootDirFolders.isdir] == 1;
    rootDirFolders = rootDirFolders(foldersLogical);
       
    % variables relevant to analysis
    samplesPerMilliSecond = 10;
    risePref = 1;
    fullEventLogicalCol = 1;        % logical value for inclusion of event in full event measurement    
    amplitudeLogicalCol = 2;        % logical value for inclusion of event in amplitude measurement
    frequencyLogicalCol = 3;        % logical value for inclusion of event in frequency measurement
    amplitudeValueCol = 4;          % measurement of event amplitude 
    riseTimeValueCol = 5;           % measurement of rise time
    riseSlopeValueCol = 6;          % measurement of rise slope
%     rise50TimeCol = 7;              % sample point at which mini rise 50 occurs
%     decay50TimeCol = 8;             % sample point at which mini decay 50 occurs
    halfWidthValueCol = 9;          % measurement of event half width
    decayValueCol = 10;
    areaValueCol = 11;              % measurement of area
    eventTimeCol = 12;   
    averageTraceLogicalCol = 13;
    eventTimeConvertedCol = 14;
    intervalValueCol = 16;
      
    % variables to be read in from user input
    p = inputParser;
    addParameter(p,'exportedGroup','amplitude',@ischar);
    addParameter(p,'frequencyCalculation','all',@ischar);
    addParameter(p,'numberOfEvents',200,@isnumeric);
    addParameter(p,'eventLimit','exactly',@ischar);
    addParameter(p,'riseLimits',[10 90],@isnumeric);
    addParameter(p,'decayLimits',[80 20],@isnumeric);
    parse(p,varargin{:});
    exportGroup = validatestring(p.Results.exportedGroup,{'full', 'amplitude'});
    freqChoice = validatestring(p.Results.frequencyCalculation,{'all', 'limited'});
    eventsChoice = validatestring(p.Results.eventLimit,{'all', 'exactly'});
    numEvents = p.Results.numberOfEvents;
    riseStartValue = p.Results.riseLimits(1);
    riseEndValue = p.Results.riseLimits(2);
    decayStartValue = p.Results.decayLimits(1);
    decayEndValue = p.Results.decayLimits(2);
    
    %% carry out exporting    
    
    % iterate through folders in root directory
    for folder = 3:size(rootDirFolders)
        nextDir = rootDirFolders(folder).name;
        if ~isfolder(nextDir)
            continue;
        end
        cd(nextDir);
        filename = dir('*.mat');
        
        % ensure that there is only one save file in the folder
        if size(filename,1) > 1
            alert = sprintf('%s%s%s','Multiple save files in "', pwd,'". Experiment skipped.');
            matError = warndlg(alert);
            waitfor(matError);
            cd ..;
            continue;
        end
                    
        % try to load the necessary files and skip the folder if they
        % do not exist
        try
            load(filename.name, 'selectedEvents', 'averageTrace','allTraces',...
                'preEventSamples','postEventSamples','risePref');
        catch
            cd ..;
            continue;
        end
        
        % skip the folder if the save file contains no selected events
        if sum(~isnan(selectedEvents)) == 0
            cd ..;
            continue;
        end
        
        % measure the kinetics of the average trace
        measureAverageEvent;
        
        % prune extra rows from selectedEvents
        selectedEvents = selectedEvents(~isnan(selectedEvents(:,eventTimeCol)),:);
        selectedEvents = abs(selectedEvents);

        % change the group that is exported based on user input
        switch exportGroup
            case {'full'}
                chosenGroupCol = fullEventLogicalCol;
            case {'amplitude'}
                chosenGroupCol = amplitudeLogicalCol;
        end

        % check that enough events have been selected
        if nansum(selectedEvents(:,chosenGroupCol)) < numEvents ...
                && strcmp(eventsChoice,'exactly')
            alert = sprintf('%s%s%s','Too few events in "', filename.name,'". Experiment skipped.');
            matError = warndlg(alert);
            waitfor(matError);
            cd ..;
            continue;
        end
        
        % remove extra events if necessary
        while nansum(selectedEvents(:,chosenGroupCol)) > numEvents
            selectedEvents = selectedEvents(1:end-1,:);
        end
        
        % remove extra traces if necessary
        allTraces = allTraces(:,selectedEvents(:,averageTraceLogicalCol) == 1);

        % population the organizedData structure
        cellName = convertCharsToStrings(split(filename.name,"."));
        cellName = cellName(1);
        OrganizedData(folder-2).Cell = cellName;
        OrganizedData(folder-2).Frequency = (length(selectedEvents)*1000)/(selectedEvents(end,eventTimeCol)/samplesPerMilliSecond-selectedEvents(1,eventTimeCol)/samplesPerMilliSecond);
        OrganizedData(folder-2).Amplitude = nanmean(selectedEvents(:,amplitudeValueCol));
        OrganizedData(folder-2).RiseTime = nanmean(selectedEvents(:,riseTimeValueCol));
        OrganizedData(folder-2).HalfWidth = nanmean(selectedEvents(:,halfWidthValueCol));
        OrganizedData(folder-2).RiseSlope = nanmean(selectedEvents(:,riseSlopeValueCol));        
        OrganizedData(folder-2).Area = nanmean(selectedEvents(:,areaValueCol));
        OrganizedData(folder-2).DecayTime = nanmean(selectedEvents(:,decayValueCol));
        OrganizedData(folder-2).AverageTraceRiseTime = averageTraceRiseTime;
        OrganizedData(folder-2).AverageTraceRiseSlope = averageTraceRiseSlope;
        OrganizedData(folder-2).AverageTraceDecayTau = averageTraceTau;   
        OrganizedData(folder-2).AverageTraceDecayFitRsq = averageTraceRsq;  
        OrganizedData(folder-2).AverageTrace = averageTrace;
        OrganizedData(folder-2).AllTraces = allTraces;

        % calculate inter-mEPSC intervals and add to selectedEvents
        selectedEvents(:,eventTimeConvertedCol) =  selectedEvents(:,eventTimeCol)/samplesPerMilliSecond;
        tempIMI = [];
        tempIMI(1) = nan;
        for i = 2:size(selectedEvents,1)
            tempIMI(i) = (selectedEvents(i,eventTimeConvertedCol)-selectedEvents(i-1,eventTimeConvertedCol));
        end
        tempIMI = tempIMI';
        selectedEvents(:,intervalValueCol) = tempIMI;

        % recalculate frequency if necessary, based on user input
        %
        % set numEventsLimited to the number of events in the cell to
        % account for cases in which there are less than N events being
        % exported
        if strcmp(freqChoice,'limited')
            numEventsLimited = size(selectedEvents,1);
            selectedEvents(numEventsLimited:end,intervalValueCol) = nan;
            OrganizedData(folder-2).Frequency =...
                (length(selectedEvents)*1000)/...
                ((selectedEvents(numEventsLimited,eventTimeConvertedCol)-selectedEvents(1,eventTimeConvertedCol)));
        end

        % reorganize selectedEvents and add to organizedData as a table and
        % matrix
        OrganizedData(folder-2).RawDataMatrix = selectedEvents;
        selectedEvents = selectedEvents(:,[fullEventLogicalCol, amplitudeLogicalCol,...
            frequencyLogicalCol,averageTraceLogicalCol,amplitudeValueCol,...
            riseTimeValueCol,riseSlopeValueCol,halfWidthValueCol,decayValueCol,...
            areaValueCol,eventTimeCol,eventTimeConvertedCol,intervalValueCol]);
        OrganizedData(folder-2).RawDataTable = array2table(selectedEvents);
        OrganizedData(folder-2).RawDataTable.Properties.VariableNames = dataTableColumnNames;

        % add selectedEvents to the group rawDataMatrix
        RawDataMatrix_AllCells = [RawDataMatrix_AllCells; selectedEvents];
        
        % move to next cell
        cd ..;
    end
    
    % check that all average traces are the same length and suppress
    % average trace output if they are not
    exportAverageTrace = 1;
    for i = 1:size(OrganizedData,2)-1
        if length(OrganizedData(i).AverageTrace) ~= length(OrganizedData(i+1).AverageTrace)
            if isempty(OrganizedData(i).AverageTrace) || isempty(OrganizedData(i+1).AverageTrace)
                continue;
            else
                alert = 'Average traces are different lengths. Please fix and re-export.';
                matError = warndlg(alert);
                waitfor(matError);
                exportAverageTrace = 0;
                break;
            end
        end
    end
    
    % reorder organizedData fields
    fieldOrder = {'Cell','RawDataMatrix','RawDataTable','AllTraces',...
        'Frequency','Amplitude','RiseTime','HalfWidth','RiseSlope',...
        'Area','DecayTime','AverageTrace','AverageTraceRiseTime',...
        'AverageTraceRiseSlope','AverageTraceDecayTau','AverageTraceDecayFitRsq'};
    OrganizedData = orderfields(OrganizedData,fieldOrder);
    
    % convert data matrix to data table
    if ~isempty(RawDataMatrix_AllCells)
        RawDataTable_AllCells = array2table(RawDataMatrix_AllCells);
        RawDataTable_AllCells.Properties.VariableNames = dataTableColumnNames;
    else
        return;
    end
    
    % calculate group average trace
    if exportAverageTrace && isfield(OrganizedData,'AverageTrace')
        AverageTrace_AllCells = mean([OrganizedData.AverageTrace],2);
    end

    function measureAverageEvent
    % measures the rise time and slope of the average trace rise
    % fits a single exponential to measure the decay of the average event trace    
        
        [averageTraceMinVal,averageTraceMinIndex] = min(averageTrace(:,1));
        totalSamples = preEventSamples + postEventSamples;
        
        % interpolate between sample points to generate fine-scale array of decay values
        averageTraceDecayArray = [];
        for i = 1:((totalSamples + 1) - averageTraceMinIndex)
            tempArray = linspace(averageTrace(averageTraceMinIndex+(i-1),1),...
                averageTrace(averageTraceMinIndex+i,1),101);
            averageTraceDecayArray(100*i-99:100*i,1) = tempArray(2:101);
        end
        
        % generate logical array for values that are in the desired range of the decay
        for i = 1:size(averageTraceDecayArray,1)
            averageTraceDecayLogical(i,1) =...
                ((averageTraceMinVal*(decayStartValue/100)) < averageTraceDecayArray(i,1))...
                && (averageTraceDecayArray(i,1) < (averageTraceMinVal*(decayEndValue/100)));
        end
        
        % create selected decay array
        averageTraceDecayArraySelect = averageTraceDecayArray(averageTraceDecayLogical,1);
        averageTraceDecayArraySelect(:,2) = (1:length(averageTraceDecayArraySelect))/1000;
        
        % fit single exponential decay to selected array
        [fitobj,gof] =...
            fit(averageTraceDecayArraySelect(:,2),averageTraceDecayArraySelect(:,1),'exp1','StartPoint',[0 -1]);
        averageTraceTau = 1/fitobj.b;
        averageTraceRsq = gof.rsquare;
        
        if risePref == 0
            averageTraceRiseTime = (averageTraceMinIndex - preEventSamples)/samplesPerMilliSecond;
            averageTraceRiseSlope = averageTraceMinVal/averageTraceRiseTime;
            return;
        end
        
        % interpolate between sample points to generate fine-scale array of rise values
        averageTraceSub = averageTrace(preEventSamples+1:averageTraceMinIndex);
        averageTraceRiseArray = [];
        for i = 1:length(averageTraceSub)-1
            tempArray = linspace(averageTraceSub(i,1), averageTraceSub(i+1,1),101);
            averageTraceRiseArray(100*i-99:100*i,1) = tempArray(2:101);         
        end
        
        % generate logical array for values that are in the desired range of the decay
        for i = 1:size(averageTraceRiseArray,1)
            averageTraceRiseLogical(i,1) =...
                ((averageTraceMinVal*(riseStartValue/100)) > averageTraceRiseArray(i,1))...
                && (averageTraceRiseArray(i,1) > (averageTraceMinVal*(riseEndValue/100)));
        end
        
        % create selected rise array
        averageTraceRiseArraySelect = averageTraceRiseArray(averageTraceRiseLogical,1);
        averageTraceRiseArraySelect(:,2) = (1:length(averageTraceRiseArraySelect))/100;
        
        % measure selected rise array
        averageTraceRiseTime =...
            (averageTraceRiseArraySelect(end,2) - averageTraceRiseArraySelect(1,2))/...
            samplesPerMilliSecond;
        averageTraceRiseSlope =...
            (averageTraceRiseArraySelect(end,1) - averageTraceRiseArraySelect(1,1))/...
            averageTraceRiseTime*-1;
    end
end