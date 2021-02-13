function exportDataGUI   
    
%% initialize variables

    % export parameters   
    exportGroup = 'Amplitude';
    numEvents = 200;
    freqChoice = 'From first N events';
    eventsChoice = 'Exactly N events';
    riseStartValue = 10;            % start of average trace rise measurement
    riseEndValue = 90;              % end of average trace rise measurement
    decayStartValue = 80;           % start of average trace rise measurement
    decayEndValue = 20;             % end of average trace rise measurement
    
    % output variables
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
    
    % variables needed from analysis file
    averageTrace = [];
    selectedEvents = [];
    allTraces = [];
    preEventSamples = [];
    postEventSamples = [];
    risePref = [];
    
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
             
    %% initialize export GUI
    
    % create and position main panel
    mainPanel = uifigure;
    mainPanelWidth = mainPanel.Position(3);
    mainPanelHeight = mainPanel.Position(4);
      
    % radio button group for export group selection
    exportGroupHeight = 0.2*mainPanelHeight;
    exportGroupWidth = 0.2*mainPanelWidth;
    exportGroupCheck = uibuttongroup('Parent',mainPanel,...
        'Title','Group to Export',...
        'SelectionChangedFcn',@exportGroupChange,...
        'Position',[mainPanelWidth*0.15-(exportGroupWidth/2) mainPanelHeight*0.675 exportGroupWidth exportGroupHeight]);
    uiradiobutton('Parent',exportGroupCheck,...
        'Text','Full event',...
        'Position',[10 0.55*exportGroupHeight 100 15]);
    uiradiobutton('Parent',exportGroupCheck,...
        'Text','Amplitude',...
        'Position',[10 0.3*exportGroupHeight 100 15],...
        'Value',true);
    uiradiobutton('Parent',exportGroupCheck,...
        'Text','Frequency',...
        'Position',[10 0.05*exportGroupHeight 100 15]);
    
    % labels and fields relating to the number of events to export
    numEeventsHeight = 0.2*mainPanelHeight;
    numEventsWidth = 0.25*mainPanelWidth;
    numEventsCheck = uibuttongroup('Parent',mainPanel,...
        'Title','Event # Limits',...
        'SelectionChangedFcn',@eventsChange,...
        'Position',[mainPanelWidth*0.45-(numEventsWidth/2) mainPanelHeight*0.675 numEventsWidth numEeventsHeight]);
    uiradiobutton('Parent',numEventsCheck,...
        'Text','Exactly N events',...
        'Position',[10 0.425*numEeventsHeight 150 15]);
    uiradiobutton('Parent',numEventsCheck,...
        'Text','Up to N events',...
        'Position',[10 0.1*numEeventsHeight 150 15]);
    
    % radio button group for frequency calculation preference
    freqpPrefHeight = 0.2*mainPanelHeight;
    freqPrefWidth = 0.3*mainPanelWidth;
    freqPrefCheck = uibuttongroup('Parent',mainPanel,...
        'Title','Frequency Calculation',...
        'SelectionChangedFcn',@freqPrefChange,...
        'Position',[mainPanelWidth*0.8-(freqPrefWidth/2) mainPanelHeight*0.675 freqPrefWidth freqpPrefHeight]);
    uiradiobutton('Parent',freqPrefCheck,...
        'Text','From first N events',...
        'Position',[10 0.425*freqpPrefHeight 150 15]);
    uiradiobutton('Parent',freqPrefCheck,...
        'Text','From all events',...
        'Position',[10 0.1*freqpPrefHeight 150 15]);
    
    % labels and fields relating to the number of events to export
    uilabel('Parent',mainPanel,...
        'Text','Number of Events (N)',...
        'fontweight', 'bold',...
        'HorizontalAlignment','Center',...
        'Position',[mainPanelWidth*0.45-(150/2) mainPanelHeight*0.55 150 20]);
    exportNumField = uieditfield(mainPanel,...
        'numeric',...
        'Value',numEvents,...
        'ValueChangedFcn',@numEventsUpdate,...
        'Position',[mainPanelWidth*0.6-(30/2) mainPanelHeight*0.55 30 20],...
        'HorizontalAlignment','Center');
    
    % average trace rise measurement preferences
    uilabel('Parent',mainPanel,...
        'Text','Average Trace',...
        'fontweight', 'bold',...
        'HorizontalAlignment','Center',...
        'Position',[mainPanelWidth*0.333-(200/2) mainPanelHeight*0.42 200 20]);
    uilabel('Parent',mainPanel,...
        'Text','Rise Measurement',...
        'fontweight', 'bold',...
        'HorizontalAlignment','Center',...
        'Position',[mainPanelWidth*0.333-(200/2) mainPanelHeight*0.38 200 20]);
    riseStartField = uieditfield(mainPanel,...
        'numeric',...
        'Value',riseStartValue,...
        'ValueChangedFcn',@averageTraceMeasurementUpdate,...
        'Position',[mainPanelWidth*0.376-(30/2) mainPanelHeight*0.32 30 20],...
        'HorizontalAlignment','Center');
    uilabel('Parent',mainPanel,...
        'Text','Begin %',...
        'fontweight', 'bold',...
        'HorizontalAlignment','Center',...
        'Position',[mainPanelWidth*0.296-(50/2) mainPanelHeight*0.32 60 20]);
    riseEndField = uieditfield(mainPanel,...
        'numeric',...
        'Value',riseEndValue,...
        'ValueChangedFcn',@averageTraceMeasurementUpdate,...
        'Position',[mainPanelWidth*0.376-(30/2) mainPanelHeight*0.26 30 20],...
        'HorizontalAlignment','Center');
    uilabel('Parent',mainPanel,...
        'Text','End %',...
        'fontweight', 'bold',...
        'HorizontalAlignment','Center',...
        'Position',[mainPanelWidth*0.296-(50/2) mainPanelHeight*0.26 50 20]);
    
    % average trace decay measurement preferences
    uilabel('Parent',mainPanel,...
        'Text','Average Trace',...
        'fontweight', 'bold',...
        'HorizontalAlignment','Center',...
        'Position',[mainPanelWidth*0.667-(225/2) mainPanelHeight*0.42 225 20]);
    uilabel('Parent',mainPanel,...
        'Text','Decay Measurement',...
        'fontweight', 'bold',...
        'HorizontalAlignment','Center',...
        'Position',[mainPanelWidth*0.667-(225/2) mainPanelHeight*0.38 225 20]);
    decayStartField = uieditfield(mainPanel,...
        'numeric',...
        'Value',decayStartValue,...
        'ValueChangedFcn',@averageTraceMeasurementUpdate,...
        'Position',[mainPanelWidth*0.71-(30/2) mainPanelHeight*0.32 30 20],...
        'HorizontalAlignment','Center');
    uilabel('Parent',mainPanel,...
        'Text','Begin %',...
        'fontweight', 'bold',...
        'HorizontalAlignment','Center',...
        'Position',[mainPanelWidth*0.63-(50/2) mainPanelHeight*0.32 60 20]);
    decayEndField = uieditfield(mainPanel,...
        'numeric',...
        'Value',decayEndValue,...
        'ValueChangedFcn',@averageTraceMeasurementUpdate,...
        'Position',[mainPanelWidth*0.71-(30/2) mainPanelHeight*0.26 30 20],...
        'HorizontalAlignment','Center');
    uilabel('Parent',mainPanel,...
        'Text','End %',...
        'fontweight', 'bold',...
        'HorizontalAlignment','Center',...
        'Position',[mainPanelWidth*0.63-(50/2) mainPanelHeight*0.26 50 20]);
    
    uibutton('Parent',mainPanel,...
        'Text',sprintf('%s\n%s','Begin','Export'),...
        'ButtonPushedFcn',@beginExport,...
        'fontweight', 'bold',...
        'Position',[mainPanelWidth*0.2-(100/2) mainPanelHeight*0.1 100 40]);
    
    uibutton('Parent',mainPanel,...
        'Text','Exit',...
        'ButtonPushedFcn',@exitAnalysis,...
        'fontweight', 'bold',...
        'Position',[mainPanelWidth*0.8-(100/2) mainPanelHeight*0.1 100 40]); 
    
    %% wait for user input    
    
    uiwait(mainPanel);
    
    %% export functions
    
    function beginExport(~,~)
        
        % define variables on each button click
        OrganizedData = struct();
        RawDataMatrix_AllCells = [];
%         rawDataTable_allCells = table();
    
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
                uialert(mainPanel,alert,'');
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
                case {'Full event'}
                    chosenGroupCol = fullEventLogicalCol;
                case {'Amplitude'}
                    chosenGroupCol = amplitudeLogicalCol;
            end

            % check that enough events have been selected
            if nansum(selectedEvents(:,chosenGroupCol)) < numEvents ...
                    && strcmp(eventsChoice,'Exactly N events')
                alert = sprintf('%s%s%s','Too few events in "', filename.name,'". Experiment skipped.');
                uialert(mainPanel,alert,'','Icon','warning');
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
            if strcmp(freqChoice,'From first N events')
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
                    uialert(mainPanel,alert,'');
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
        
        % calculate and export average trace to base workspace
        if exportAverageTrace && isfield(OrganizedData,'AverageTrace')
            AverageTrace_AllCells = mean([OrganizedData.AverageTrace],2);
            assignin('base','AverageTrace_AllCells',AverageTrace_AllCells);
        end
        
        % export remaining variables to workspace
        assignin('base','OrganizedData',OrganizedData);
        assignin('base','RawDataMatrix_AllCells',RawDataMatrix_AllCells);
        assignin('base','RawDataTable_AllCells',RawDataTable_AllCells);
        
        message = 'Export successful.';
        uialert(mainPanel,message,'','Icon','success');
    end
    
    function exitAnalysis(~,~)
    % exit the GUI
        delete(mainPanel);
    end

    function exportGroupChange(~,event)
    % changes which group is auto-exported
        exportGroup = event.NewValue.Text;
    end

    function freqPrefChange(~,event)
    % changes how frequency is calculated during export
        freqChoice = event.NewValue.Text;
    end

    function eventsChange(~,event)
    % changes the limits on event numbers
        eventsChoice = event.NewValue.Text;
    end

    function numEventsUpdate(~,~)
    % changes how many events are exported
        numEvents = exportNumField.Value;
    end

    function averageTraceMeasurementUpdate(~,~)
    % changes the start and end values for average trace kinetics
    % measurements
        riseStartValue = riseStartField.Value;
        riseEndValue = riseEndField.Value;
        decayStartValue = decayStartField.Value;
        decayEndValue = decayEndField.Value;
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