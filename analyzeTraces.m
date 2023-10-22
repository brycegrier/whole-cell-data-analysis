function analyzeTraces
    % author: Bryce Grier 
    % last updated 2020.03.03
    % contact: bdgrier@gmail.com
    
%% introduction
    % This program can be used to analyze whole-cell electrophysiology data. It currently accepts
    % '.txt' files. Files should be formatted as a column vector of current values in pA. Currently,
    % only negative current can be analyzed. The ability to analyze positive current will be added
    % in the future.
    
    % As events are selected, they can be sorted into 1 of 3 analysis groups:
    %   full event = rise and decay of event are measured
    %   amplitude = rise of event is measured
    %   frequency = event in included only in measurement of frequency
    
    % All events labeled for full analysis are added to the average event trace. Specific events
    % can be removed from the average trace by selecting them on either the raw events plot or on 
    % the scaled events plot.
    
    % Keyboard functionality requires the main panel of the GUI to have focus. Clicking in certain
    % areas moves focus to a child component of the main panel. To return focus to the main panel, 
    % simply click anywhere where there is not a child component.
    
    % The delete button has two functions:
    %   when an event is selected, it deletes the selected event
    %   when no event is selected, it clears all events from the current view window

%% initialize shared variables

    % analysis parameters
    RMS = 2;                        % default value for root mean square noise of trace
    noiseThreshold = 3*RMS;         % default threshold for event detection 
    decayStartPercent = 90;              % default percentage of decay to measure from
    decayEndPercent = 37;              % default percentage of decay to measure to
    riseStartPercent = 10;              % default percentage of rise to measure from
    riseEndPercent = 90;              % default percentage of rise to measure to
    samplesPerMilliSecond = 10;     % sampling rate/1000
    
    % diretory and cell strings
    cellName = "";                  % string containing experiment cell name
%     fileType = "";                  % string containing experiment file type
    fileName = "";                  % string containing experiment file name
    matliststrings = string();      % string of matlab files present in experiment folder
    traceliststrings = string();    % string of traces present in experiment folder
        
    % display variables
    yMax = 10;                      % default maximum y axis value of plotted trace
    yMin = -50;                     % default minimum y axis value of plotted trace
    yOffset = 0;                    % default y offset of plotted trace
    sortedColumn = 1;               % column number on which data table is sorted 
    ascendLogical = 1;              % logical value indicating direction of sorting
    windowScope = 800;              % default width of viewing window in sample points
    currentWindow = [];             % array of sample points currently in view
    autoZoom = 1;                   % logical value for auto zoon on event selection
    traceAlignment = 'Align By Threshold'; % value for how to align traces
    
    % trace variables
    traceSamples = [];              % imported whole cell trace
    trace_first_der = [];           % first derivative of whole cell trace
    traceValueCol = 1;              % membrane current values
    traceTimeCol = 2;               % sample points 
    eventPlotLogicalCol = 3;        % logical values for presence of event threshold
    eventPlotEndCol = 4;            % sample points of event peaks
    
    % data table column values
    fullEventLogicalCol = 1;        % logical value for inclusion of event in full event measurement    
    amplitudeLogicalCol = 2;        % logical value for inclusion of event in amplitude measurement
    frequencyLogicalCol = 3;        % logical value for inclusion of event in frequency measurement
    amplitudeValueCol = 4;          % measurement of event amplitude 
    riseTimeValueCol = 5;       % measurement of event 10-90 rise time
    riseSlopeValueCol = 6;      % measurement of event 10-90 slope
    rise50TimeCol = 7;              % sample point at which event rise 50 occurs
    decay50TimeCol = 8;             % sample point at which event decay 50 occurs
    halfWidthValueCol = 9;          % measurement of event half width
    decayValueCol = 10;             % measurement of decay time to desired percentage of peak value
    aucValueCol = 11;               % measurement of area to desired percentage of peak value
    eventTimeCol = 12;              % when event occurs
    averageTraceLogicalCol = 13;    % logical value for inclusion of event in average trace  
    
    % selection variables
    eventCurrentlySelected = false; % logical value for whether event is selected
    eventIndex = 0;                 % row of selectedEvents current being modified
    selectedEvents = nan(500,15);   % matrix containing measurements of events
    eventPeakTime = [];             % time of peak of currently selected event
    eventThresholdTime = [];        % time of threshold of currently selected event
    eventPeakValue = [];            % value of peak of currently selected event
    eventThresholdValue = [];       % value of threshold of currently selected event
    eventDecayAUC = [];             % area of decay portion of currently selected event
    eventRiseAUC = [];              % area of rise portion of currently selected event
    
    % average trace variables
    preEventSamples = 10;           % # of samples before threshold in average trace
    postEventSamples = 150;         % # of samples after threshold in average trace
    totalSamples = preEventSamples + postEventSamples;      % total # of samples in average trace
    allTraces = [];                 % totalSamples x n event matrix of event traces
    averageTrace = [];              % column vector with mean of each row of allTraces
    eventPlots = gobjects(1,size(selectedEvents,1));        %place holders for trace plot objects
    eventPlotsScaled = gobjects(1,size(selectedEvents,1));  %place holders for trace plot objects
    
    % misc
    updatingLogical = false;
    averageTraceUpdate = false;
    savePath = '';
          
%% set root directory
    % the root directory should contain experiments separated into folders
    % specific experiment folders can be navigated to within the GUI
    rootDir = pwd;
   
%% get screen dimensions
    % obtain information to assist in dynamically creating the GUI

    % obtain information on screen sizes
    screenDims = get(0,'ScreenSize');
    screenOffset = [0 0];

    % setting dimension variables for later use in generating the GUI layout
    screenWidth = screenDims(3);
    screenHeight = screenDims(4);
    
%% set working directory
    % populate the list of experiment folders that you are able to choose from
    
    % get list of items in the root directory
    dirlist = dir();
    dirliststrings = string();
    for dirIndex = 3:size(dirlist,1)
        dirliststrings(dirIndex-1) = convertCharsToStrings(dirlist(dirIndex).name);
    end
    
    % remove non-folder items from the list of strings and add a blank string to the beginning
    dirliststrings = dirliststrings(isfolder(dirliststrings));
%     dirliststrings = dirliststrings(~strncmp('exc',dirliststrings,3));
    dirliststrings = [string() dirliststrings];      
      
%% initialize main panel
    % create the main GUI panel and add elements to it
    
    % intialize and position main panel
    mainPanel = uifigure('Position',[screenOffset(1) screenOffset(2) 100 100]);
%     mainPanel.Position = [screenOffset(1) screenOffset(2) 100 100];
    set(mainPanel,'WindowState','maximized');
    
    % data table that will contain measurements
    dataTable = table();
    uit = uitable('Parent',mainPanel,...
        'Data',dataTable,...
        'Position',[20 20 screenWidth/2-(30) screenHeight/2-(100)],...
        'CellSelectionCallback',@navigateToEvent,...
        'ColumnSortable',true,...
        'DisplayDataChangedFcn',@sortCallback); 
   
    % tab group that will contain tabs with buttons for interacting with the recording
    buttonTabGroup = uitabgroup('Parent',mainPanel,...
        'Position',[screenWidth/2+(10) 20 screenWidth/2-(30) screenHeight/2-(80)]); 
    
    % tab group that will contain plots of the main recording and of individual events 
    plotTabGroup = uitabgroup('Parent',mainPanel,...
        'Position',[20 screenHeight/2-50 screenWidth-40 screenHeight/2-30],...
        'SelectionChangedFcn',@evaluateCurrentPlotTab);
    
    % counters for number of events sorted into each analysis group
    avgCount = uilabel('Parent',mainPanel,...
        'HorizontalAlignment','Center',...
        'Text',sprintf('%s%i','# in Average Trace: ',nansum(selectedEvents(:,averageTraceLogicalCol))),...
        'Position',[screenWidth*0.10-75 screenHeight/2-75 150 20],...
        'fontweight', 'bold');   
    fullCount = uilabel('Parent',mainPanel,...
        'HorizontalAlignment','Center',...
        'Text',sprintf('%s%i','# in Full Event: ',nansum(selectedEvents(:,fullEventLogicalCol))),...
        'Position',[screenWidth*0.20-75 screenHeight/2-75 150 20],...
        'fontweight', 'bold');
    ampCount = uilabel('Parent',mainPanel,...
        'HorizontalAlignment','Center',...
        'Text',sprintf('%s%i','# in Amplitude: ',nansum(selectedEvents(:,amplitudeLogicalCol))),...
        'Position',[screenWidth*0.30-75 screenHeight/2-75 150 20],...
        'fontweight', 'bold');
    freqCount = uilabel('Parent',mainPanel,...
        'HorizontalAlignment','Center',...
        'Text',sprintf('%s%i','# in Frequency: ',nansum(selectedEvents(:,frequencyLogicalCol))),...
        'Position',[screenWidth*0.40-75 screenHeight/2-75 150 20],...
        'fontweight', 'bold');
    
%% create tabs for plots
    % populate the tabs that will contain plots

    % get dimensions of plot tab group for later use
    plotTabGroupDims = plotTabGroup.Position;
    plotTabGroupWidth = plotTabGroupDims(3);
    plotTabGroupHeight = plotTabGroupDims(4);
    
    % tab and plot that will display the main recording trace
    traceTab = uitab('Parent',plotTabGroup,'Title','Trace');
    tracePlot = uiaxes('Parent',traceTab,...
        'Position',[20 20 plotTabGroupWidth-30 plotTabGroupHeight-50],...
        'XTick',[]);
    tracePlot.Toolbar.Visible = 'off';
    
    % sliders that allow adjustment of view within a given window
    ySlider = uislider('Parent',traceTab,...
        'Orientation','vertical',...
        'Position',[10 25 3 plotTabGroupHeight-60],...
        'MajorTicks',[],...
        'MinorTicks',[],...
        'Limits',[-40 40],...
        'Value',0,...
        'ValueChangingFcn',@ySliderFunc);
    xSlider = uislider('Parent',traceTab,...
        'Orientation','horizontal',...
        'Position',[40 10 plotTabGroupWidth-55 3],...
        'MajorTicks',[],...
        'MinorTicks',[],...
        'Limits',[-windowScope windowScope],...
        'Value',0,...
        'ValueChangedFcn',@xSliderFunc);
    
    % tab and plots that will display overlaid events and the average event trace
    averageTraceTab = uitab('Parent',plotTabGroup,...
        'Title','Average Event');
    allTracePlot = uiaxes('Parent',averageTraceTab,...
        'XTick',[],...
        'Position',[5 10 plotTabGroupWidth/3-10 plotTabGroupHeight-40]);
    allTracePlot.Title.String = 'All Traces';
    allTracePlot.Toolbar.Visible = 'off';
    scaledTracePlot = uiaxes('Parent',averageTraceTab,...
        'XTick',[],...
        'Position',[plotTabGroupWidth*(1/3)+5 10 plotTabGroupWidth/3-10 plotTabGroupHeight-40]);
    scaledTracePlot.Title.String = 'Scaled Traces';
    scaledTracePlot.Toolbar.Visible = 'off';
    averageTracePlot = uiaxes('Parent',averageTraceTab,...
        'XTick',[],...
        'Position',[plotTabGroupWidth*(2/3)+5 10 plotTabGroupWidth/3-10 plotTabGroupHeight-40]);
    averageTracePlot.Title.String = 'Average Trace';
    averageTracePlot.Toolbar.Visible = 'off';
            
%% create navigation tab
    % create and populate the tab that initializes analysis
    
    % create tab and store dimensions for later use
    navigationTab = uitab('Parent',buttonTabGroup,...
        'Title','Navigation');
    navigationTabDims = navigationTab.Position;
    navigationTabWidth = navigationTabDims(3);
    navigationTabHeight = navigationTabDims(4);
    
    % list boxes containing experiments, recording files, and existing analysis files
    uilabel('Parent',navigationTab,...
        'Text','Choose an experiment',...
        'HorizontalAlignment','Center',...
        'Position',[navigationTabWidth*0.15-(175/2) navigationTabHeight*0.775 175 40],...
        'fontweight', 'bold');
    directoryControl = uilistbox('Parent',navigationTab,...
        'Items',dirliststrings,...
        'ValueChangedFcn',@populateLists,...
        'Position',[navigationTabWidth*0.15-(150/2) navigationTabHeight*0.55-(125/2) 150 125]);
    uilabel('Parent',navigationTab,...
        'Text',sprintf('%s\n%s','Choose a trace',' to begin analysis'),...
        'HorizontalAlignment','Center',...
        'fontweight', 'bold',...
        'Position',[navigationTabWidth*0.5-(175/2) navigationTabHeight*0.775 175 40]);
    mainTraceControl = uilistbox('Parent',navigationTab,...
        'Items',traceliststrings,...
        'Position',[navigationTabWidth*0.5-(150/2) navigationTabHeight*0.55-(125/2) 150 125]);
    uilabel('Parent',navigationTab,...
        'Text',sprintf('%s\n%s','Choose an existing','file to resume analysis'),...
        'HorizontalAlignment','Center',...
        'fontweight', 'bold',...
        'Position',[navigationTabWidth*0.85-(200/2) navigationTabHeight*0.775 200 40]);
    analysisList = uilistbox('Parent',navigationTab,...
        'Items',matliststrings,...
        'Position',[navigationTabWidth*0.85-(150/2) navigationTabHeight*0.55-(125/2) 150 125]);
       
    % buttons to initialize, save, and end analysis
    uibutton('Parent',navigationTab,...
        'Text',sprintf('%s\n%s','Begin','New Analysis'),...
        'ButtonPushedFcn',@beginAnalysis,...
        'fontweight', 'bold',...
        'Position',[navigationTabWidth*0.2-(100/2) navigationTabHeight*0.1 100 40]);
    uibutton('Parent',navigationTab,...
        'Text',sprintf('%s\n%s','Load Existing','Analysis'),...
        'ButtonPushedFcn',@resumeAnalysis,...
        'fontweight', 'bold',...
        'Position',[navigationTabWidth*0.4-(100/2) navigationTabHeight*0.1 100 40]);
    uibutton('Parent',navigationTab,...
        'Text',sprintf('%s\n%s','Save','Analysis'),...
        'ButtonPushedFcn',@saveAnalysis,...
        'fontweight', 'bold',...
        'Position',[navigationTabWidth*0.6-(100/2) navigationTabHeight*0.1 100 40]);  
    uibutton('Parent',navigationTab,...
        'Text','Exit',...
        'ButtonPushedFcn',@exitAnalysis,...
        'fontweight', 'bold',...
        'Position',[navigationTabWidth*0.8-(100/2) navigationTabHeight*0.1 100 40]); 

%% create settings tab
    % create and populate the tab that contains analysis settings

    % create tab and store dimensions for later use
    settingsTab = uitab('Parent',buttonTabGroup,...
        'Title','Settings');
    settingsTabDims = settingsTab.Position;
    settingsTabWidth = settingsTabDims(3);
    settingsTabHeight = settingsTabDims(4);
    
    % radio buttons for average trace alignment preference
        traceButtonWidth = settingsTabWidth*0.25;
        traceButtonHeight = settingsTabHeight*0.225;
        traceAlignButton  = uibuttongroup('Parent',settingsTab,...
            'Title','Average Trace Alignment',...
            'fontweight','bold',...
            'SelectionChangedFcn',@alignmentChange,...
            'Position',[settingsTabWidth*0.2-(traceButtonWidth/2) settingsTabHeight*0.75-(traceButtonHeight/2) traceButtonWidth traceButtonHeight]);
        uiradiobutton('Parent',traceAlignButton,...
            'Text','Align By Threshold',...
            'fontweight', 'bold',...
            'Position',[traceButtonWidth*0.5-(150/2) traceButtonHeight*0.5-(20/2) 150 20]); 
        uiradiobutton('Parent',traceAlignButton,...
            'Text','Align By Peak',...
            'fontweight', 'bold',...
            'Position',[traceButtonWidth*.5-(150/2) traceButtonHeight*0.2-(20/2) 150 20]); 
    
    % checkbox for auto-zoom on event selection
    zoomCheck = uicheckbox('Parent',settingsTab,...
        'Text','Auto-zoom on event selection',...
        'fontweight','bold',...
        'Value',autoZoom,...
        'ValueChangedFcn',@zoomChange,...
        'Position',[settingsTabWidth*0.8-(200/2) settingsTabHeight*0.85-(40) 200 20]);
      
    % controls for measuring and editing RMS/noise threshold
    uibutton('Parent',settingsTab,...
        'Text','Measure',...
        'ButtonPushedFcn',@measureRMS,...
        'fontweight', 'bold',...
        'Position',[settingsTabWidth*0.08-(60/2) settingsTabHeight*0.505 60 20]); 
    uilabel('Parent',settingsTab,...
        'Text','RMS =',...
        'fontweight', 'bold',...
        'HorizontalAlignment','Center',...
        'Position',[settingsTabWidth*0.16-(50/2) settingsTabHeight*0.5 50 20]);
    rmsField = uieditfield(settingsTab,...
        'numeric',...
        'Value',RMS,...
        'ValueChangedFcn',@rmsUpdate,...
        'Position',[settingsTabWidth*0.22-(30/2) settingsTabHeight*0.5 40 20],...
        'HorizontalAlignment','Center');
    cutoffText = uilabel('Parent',settingsTab,...
        'Text',strcat("Noise Threshold: ",num2str(noiseThreshold)," pA"),...
        'Position',[settingsTabWidth*0.15-(175/2) settingsTabHeight*0.425 175 20],...
        'fontweight', 'bold',...
        'HorizontalAlignment','Center');
    
    % labels and fields dealing with how event rise time is measured
    uilabel('Parent',settingsTab,...
        'Text','Rise Time Measurement',...
        'fontweight', 'bold',...
        'HorizontalAlignment','Center',...
        'Position',[settingsTabWidth*0.35-(160/2) settingsTabHeight*0.25 160 20]);
    riseStartField = uieditfield(settingsTab,...
        'numeric',...
        'Value',riseStartPercent,...
        'ValueChangedFcn',@fieldUpdate,...
        'Position',[settingsTabWidth*0.30-(30/2) settingsTabHeight*0.175 30 20],...
        'HorizontalAlignment','Center');
    uilabel('Parent',settingsTab,...
        'Text','%',...
        'fontweight', 'bold',...
        'HorizontalAlignment','Center',...
        'Position',[settingsTabWidth*0.33-(20/2) settingsTabHeight*0.175 20 20]);
    uilabel('Parent',settingsTab,...
        'Text','to',...
        'fontweight', 'bold',...
        'HorizontalAlignment','Center',...
        'Position',[settingsTabWidth*0.35-(20/2) settingsTabHeight*0.175 20 20]);
    riseEndField = uieditfield(settingsTab,...
        'numeric',...
        'Value',riseEndPercent,...
        'ValueChangedFcn',@fieldUpdate,...
        'Position',[settingsTabWidth*0.39-(30/2) settingsTabHeight*0.175 30 20],...
        'HorizontalAlignment','Center');
    uilabel('Parent',settingsTab,...
        'Text','%',...
        'fontweight', 'bold',...
        'HorizontalAlignment','Center',...
        'Position',[settingsTabWidth*0.42-(20/2) settingsTabHeight*0.175 20 20]);
    
    % labels and fields dealing with how event decay time is measured
    uilabel('Parent',settingsTab,...
        'Text','Decay Time Measurement',...
        'fontweight', 'bold',...
        'HorizontalAlignment','Center',...
        'Position',[settingsTabWidth*0.65-(160/2) settingsTabHeight*0.25 160 20]);
    decayStartField = uieditfield(settingsTab,...
        'numeric',...
        'Value',decayStartPercent,...
        'ValueChangedFcn',@fieldUpdate,...
        'Position',[settingsTabWidth*0.60-(30/2) settingsTabHeight*0.175 30 20],...
        'HorizontalAlignment','Center');
    uilabel('Parent',settingsTab,...
        'Text','%',...
        'fontweight', 'bold',...
        'HorizontalAlignment','Center',...
        'Position',[settingsTabWidth*0.63-(20/2) settingsTabHeight*0.175 20 20]);
    uilabel('Parent',settingsTab,...
        'Text','to',...
        'fontweight', 'bold',...
        'HorizontalAlignment','Center',...
        'Position',[settingsTabWidth*0.65-(20/2) settingsTabHeight*0.175 20 20]);
    decayEndField = uieditfield(settingsTab,...
        'numeric',...
        'Value',decayEndPercent,...
        'ValueChangedFcn',@fieldUpdate,...
        'Position',[settingsTabWidth*0.69-(30/2) settingsTabHeight*0.175 30 20],...
        'HorizontalAlignment','Center');
    uilabel('Parent',settingsTab,...
        'Text','%',...
        'fontweight', 'bold',...
        'HorizontalAlignment','Center',...
        'Position',[settingsTabWidth*0.72-(20/2) settingsTabHeight*0.175 20 20]);
    
    % labels and fields associated with sampling rate 
    uilabel('Parent',settingsTab,...
        'Text','Sampling Rate',...
        'fontweight', 'bold',...
        'HorizontalAlignment','Center',...
        'Position',[settingsTabWidth*0.50-(110/2) settingsTabHeight*0.5 110 20]);
    samplingField = uieditfield(settingsTab,...
        'numeric',...
        'Value',samplesPerMilliSecond,...
        'ValueChangedFcn',@fieldUpdate,...
        'Position',[settingsTabWidth*0.475-(30/2) settingsTabHeight*0.425 30 20],...
        'HorizontalAlignment','Center');
    uilabel('Parent',settingsTab,...
        'Text','kHz',...
        'fontweight', 'bold',...
        'HorizontalAlignment','Center',...
        'Position',[settingsTabWidth*0.525-(30/2) settingsTabHeight*0.425 30 20]);
    
    % labels and fields associated with average trace display parameters
    uilabel('Parent',settingsTab,...
        'Text','Samples in Average Trace',...
        'fontweight', 'bold',...
        'HorizontalAlignment','Center',...
        'Position',[settingsTabWidth*0.81-(200/2) settingsTabHeight*0.5 200 20]);
    preEventField = uieditfield(settingsTab,...
        'numeric',...
        'Value',preEventSamples,...
        'ValueChangedFcn',@sampleNumberUpdate,...
        'Position',[settingsTabWidth*0.80-(30/2) settingsTabHeight*0.425 30 20],...
        'HorizontalAlignment','Center');
    uilabel('Parent',settingsTab,...
        'Text','Pre Event',...
        'fontweight', 'bold',...
        'HorizontalAlignment','Center',...
        'Position',[settingsTabWidth*0.72-(50/2) settingsTabHeight*0.425 60 20]);
    postEventField = uieditfield(settingsTab,...
        'numeric',...
        'Value',postEventSamples,...
        'ValueChangedFcn',@sampleNumberUpdate,...
        'Position',[settingsTabWidth*0.92-(30/2) settingsTabHeight*0.425 30 20],...
        'HorizontalAlignment','Center');
    uilabel('Parent',settingsTab,...
        'Text','Decay',...
        'fontweight', 'bold',...
        'HorizontalAlignment','Center',...
        'Position',[settingsTabWidth*0.865-(50/2) settingsTabHeight*0.425 50 20]);
       
%% create analysis tab
    % create and populate the tab that contains buttons for analysis

    % create the tab
    analysisTab = uitab('Parent',buttonTabGroup,'Title','Analysis');
     
    %buttons for zooming in and out
    uibutton('Parent',analysisTab,...
        'Text',sprintf('%s\n%s','Zoom Out','X [1]'),...
        'ButtonPushedFcn',@expandXView,...
        'Position',[navigationTabWidth*0.2-(100/2) navigationTabHeight*0.8-(40) 100 40],...
        'fontweight', 'bold');
    uibutton('Parent',analysisTab,...
        'Text',sprintf('%s\n%s','Zoom In','X [2]'),...
        'ButtonPushedFcn',@shrinkXView,...
        'Position',[navigationTabWidth*0.4-(100/2) navigationTabHeight*0.8-(40) 100 40],...
        'fontweight', 'bold');
    uibutton('Parent',analysisTab,...
        'Text',sprintf('%s\n%s','Zoom Out','Y [3]'),...
        'ButtonPushedFcn',@expandYView,...
        'Position',[navigationTabWidth*0.6-(100/2) navigationTabHeight*0.8-(40) 100 40],...
        'fontweight', 'bold');
    uibutton('Parent',analysisTab,...
        'Text',sprintf('%s\n%s','Zoom In','Y [4]'),...
        'ButtonPushedFcn',@shrinkYView,...
        'Position',[navigationTabWidth*0.8-(100/2) navigationTabHeight*0.8-(40) 100 40],...
        'fontweight', 'bold');
    
    % buttons for shifting the position of the threshold and peak of a selected event
    uibutton('Parent',analysisTab,...
        'Text',sprintf('%s\n%s','Threshold Shift','Back [q]'),...
        'ButtonPushedFcn',@backThreshold,...
        'Position',[navigationTabWidth*0.2-(100/2) navigationTabHeight*0.6-(40) 100 40],...
        'fontweight', 'bold');
    uibutton('Parent',analysisTab,...
        'Text',sprintf('%s\n%s','Threshold Shift','Forward [w]'),...
        'ButtonPushedFcn',@forwardThreshold,...
        'Position',[navigationTabWidth*0.4-(100/2) navigationTabHeight*0.6-(40) 100 40],...
        'fontweight', 'bold');
    uibutton('Parent',analysisTab,...
        'Text',sprintf('%s\n%s','Peak Shift','Back [e]'),...
        'ButtonPushedFcn',@backPeak,...
        'Position',[navigationTabWidth*0.6-(100/2) navigationTabHeight*0.6-(40) 100 40],...
        'fontweight', 'bold');
    uibutton('Parent',analysisTab,...
        'Text',sprintf('%s\n%s','Peak Shift','Forward [r]'),...
        'ButtonPushedFcn',@forwardPeak,...
        'Position',[navigationTabWidth*0.8-(100/2) navigationTabHeight*0.6-(40) 100 40],...
        'fontweight', 'bold');
    
    % buttons for adding a selected event to a specific analysis group
    uibutton('Parent',analysisTab,...
        'Text',sprintf('%s\n%s','Full Event','Sort [a]'),...
        'ButtonPushedFcn',@addToFullDecayGroup,...
        'Position',[navigationTabWidth*0.2-(100/2) navigationTabHeight*0.4-(40) 100 40],...
        'fontweight', 'bold');
    uibutton('Parent',analysisTab,...
        'Text',sprintf('%s\n%s','Amplitude','Sort [s]'),...
        'ButtonPushedFcn',@addToAmplitudeGroup,...
        'Position',[navigationTabWidth*0.4-(100/2) navigationTabHeight*0.4-(40) 100 40],...
        'fontweight', 'bold');
    uibutton('Parent',analysisTab,...
        'Text',sprintf('%s\n%s','Frequency','Sort [d]'),...
        'ButtonPushedFcn',@addToFrequencyGroup,...
        'Position',[navigationTabWidth*0.6-(100/2) navigationTabHeight*0.4-(40) 100 40],...
        'fontweight', 'bold');
    uibutton('Parent',analysisTab,...
        'Text',sprintf('%s\n%s','Delete Event','[f]'),...
        'ButtonPushedFcn',@deleteEvent,...
        'Position',[navigationTabWidth*0.8-(100/2) navigationTabHeight*0.4-(40) 100 40],...
        'fontweight', 'bold');
    
    % buttons for moving through viewing windows
    uibutton('Parent',analysisTab,...
        'Text',sprintf('%s\n%s','Prev. Window','[z]'),...
        'ButtonPushedFcn',@previousWindow,...
        'Position',[navigationTabWidth*0.2-(100/2) navigationTabHeight*0.2-(40) 100 40],...
        'fontweight', 'bold');
    uibutton('Parent',analysisTab,...
        'Text',sprintf('%s\n%s','Next Window','[x]'),...
        'ButtonPushedFcn',@nextWindow,...
        'Position',[navigationTabWidth*0.4-(100/2) navigationTabHeight*0.2-(40) 100 40],...
        'fontweight', 'bold');
    
    % misc. buttons
    uibutton('Parent',analysisTab,...
        'Text',sprintf('%s\n%s','Add Freq.','to Amp.'),...
        'ButtonPushedFcn',@addFreqToAmp,...
        'Position',[navigationTabWidth*0.6-(100/2) navigationTabHeight*0.2-(40) 100 40],...
        'fontweight', 'bold');
    uibutton('Parent',analysisTab,...
        'Text',sprintf('%s\n%s','Add Amp.','to Full'),...
        'ButtonPushedFcn',@addAmpToFull,...
        'Position',[navigationTabWidth*0.8-(100/2) navigationTabHeight*0.2-(40) 100 40],...
        'fontweight', 'bold');
    
%% wait for user input
    % pause program execution to allow for interaction with GUI
    
    uiwait(mainPanel);

%% initialization functions
    function beginAnalysis(~,~)
    % begin analysis on a new experiment
    
        % ignore button click if an event is currently selected
        if (eventCurrentlySelected == true)
            uialert(mainPanel, 'Please sort or delete the selected event.','');
            return;
        end
    
        if sum(~isnan(selectedEvents(:))) > 0
            decisionSave = uiconfirm(mainPanel,...
                'Save before opening a new experiment?','',...
                'Options',{'Yes','No'});
            if strcmp(decisionSave,'Yes')
                saveAnalysis;
                matlist = dir('*.mat');
                matliststrings = string();
                for matIndex = 1:size(matlist,1)
                    matliststrings(matIndex) = convertCharsToStrings(matlist(matIndex).name);
                end
                set(analysisList, 'Items', matliststrings);
            end
        end
        
        % clear plots and reset certain parameters to their default values
        cla(averageTracePlot);
        cla(allTracePlot);
        cla(scaledTracePlot);
        RMS = 2;
        windowScope = 800;
        xSlider.Limits = [-windowScope windowScope];
        ySlider.Limits = [-50 10];
        currentWindow = 1:windowScope;
        selectedEvents = NaN(500,15);
        eventCurrentlySelected = false;
        
        % turn on keyboard and click functions
        set(mainPanel, 'KeyPressFcn', @keyPressListener);
        set(mainPanel, 'WindowButtonDownFcn', @selectEvent);
        
        % import and plot recording trace
        fileName = mainTraceControl.Value;
        if fileName ~= ""
            cellName = convertCharsToStrings(split(fileName,"."));
%             fileType = cellName(2);
            cellName = cellName(1);
            importTrace;
            trace_first_der = diff(traceSamples(:,traceValueCol));
            trace_first_der = cat(1,trace_first_der,0);
            plotLocation;
            displayEventData; 
        else
            uialert(mainPanel, 'Please choose a trace for analysis.','');
            return;
        end  
        savePath = pwd;
    end

    function resumeAnalysis(~,~)
    % resume analysis that has been previously worked on and saved
    
        % ignore button click if an event is currently selected
        if (eventCurrentlySelected == true)
            uialert(mainPanel, 'Please sort or delete the selected event.','');
            return;
        end
        
        if sum(~isnan(selectedEvents(:))) > 0
            decisionSave = uiconfirm(mainPanel,...
                'Save before opening a new experiment?','',...
                'Options',{'Yes','No'});
            if strcmp(decisionSave,'Yes')
                saveAnalysis;
                matlist = dir('*.mat');
                matliststrings = string();
                for matIndex = 1:size(matlist,1)
                    matliststrings(matIndex) = convertCharsToStrings(matlist(matIndex).name);
                end
                set(analysisList, 'Items', matliststrings);
            end
        end
    
        % turn on keyboard and click functions
        set(mainPanel, 'KeyPressFcn', @keyPressListener);
        set(mainPanel, 'WindowButtonDownFcn', @selectEvent);
        
        % clear plots 
        cla(averageTracePlot);
        cla(allTracePlot);
        cla(scaledTracePlot);
        
        % check for experiment and analysis file being selected
        if isempty(directoryControl.Value)
            uialert(mainPanel, 'Please choose a folder first.','');
            return;
        end
        if isempty(analysisList.Value)
            uialert(mainPanel, 'Please choose an analysis file.','');
            return;
        end
        
        % load relevant workspace variables from saved analysis
        fileName = analysisList.Value;
        cellName = convertCharsToStrings(split(fileName,"."));
        cellName = cellName(1);
        warning('off','MATLAB:load:variableNotFound');
        load(analysisList.Value, 'dataTable', 'currentWindow', 'selectedEvents', 'traceSamples',...
            'decayStartPercent','decayEndPercent','riseStartPercent','riseEndPercent',...
            'RMS','samplesPerMilliSecond','preEventSamples','postEventSamples','autoZoom');
        warning('on','MATLAB:load:variableNotFound');
        
        % set view parameters to those of saved experiment
        windowScope = length(currentWindow);
        if (isempty(currentWindow)) || (size(currentWindow,2) == 1)
            windowScope = 500;
            currentWindow = 1:windowScope;
        end
        xSlider.Limits = [-windowScope windowScope];
        ySlider.Limits = [-50 10];

        % update displayed parameters with loaded values    
        rmsField.Value = RMS;
        noiseThreshold = 3*RMS;
        cutoffText.Text = strcat("Noise Threshold: ",num2str(noiseThreshold)," pA");
        riseStartField.Value = riseStartPercent;
        riseEndField.Value = riseEndPercent;
        decayStartField.Value = decayStartPercent;
        decayEndField.Value = decayEndPercent;
        samplingField.Value = samplesPerMilliSecond;
        preEventField.Value = preEventSamples;
        postEventField.Value = postEventSamples;
        zoomCheck.Value = autoZoom;
        
        % misc. housekeeping before analysis begins
        trace_first_der = diff(traceSamples(:,traceValueCol));
        trace_first_der = cat(1,trace_first_der,0);
        selectedEvents = sortrows(selectedEvents,eventTimeCol,'MissingPlacement','last');
        selectedEvents = selectedEvents(:,1:15);
        displayEventData;
        plotLocation;
        plotOverlaidEvents;
        updateSortCounts;
        savePath = pwd;
    end    

    function importTrace
    % import a recording trace for analysis
        
        delimiter = {''};
        startRow = 2;
        formatSpec = '%f%[^\n\r]';
        fileID = fopen(fileName,'r');
        dataArray = textscan(fileID, formatSpec, 'Delimiter', delimiter,...
            'TextType', 'string','EmptyValue', NaN, 'HeaderLines' ,startRow-1,...
            'ReturnOnError', false, 'EndOfLine', '\r\n');
        fclose(fileID);
        traceSamples = [dataArray{1:end-1}];

        % add auxiliary columns to recording trace to keep track of event locations
        for i = 1:size(traceSamples,traceValueCol)
            traceSamples(i,traceTimeCol) = i;
            traceSamples(i,eventPlotLogicalCol) = 0;
            traceSamples(i,eventPlotEndCol) = nan;
        end
    end

%% selection functions
    function selectEvent(~,~)
    % allows user to select events for analysis
        
        % determine click location within the GUI
        mainPoint = mainPanel.CurrentPoint;
        
        % reacquire plot tab group dimensions in case GUI has been moved to new window
        plotTabGroupDims = plotTabGroup.Position;
        plotTabGroupHorz = plotTabGroupDims(1)+plotTabGroupDims(3);
        plotTabGroupVert = plotTabGroupDims(2)+plotTabGroupDims(4);
        
        % check to see if click was within the trace plot
        % ignore the click if it was outside of the trace plot
        if (sum(ismember(mainPoint(1),plotTabGroupDims(1)+20:plotTabGroupHorz-10)) == 0)...
                || (sum(ismember(mainPoint(2),plotTabGroupDims(2)+20:plotTabGroupVert-30)) == 0)
            return;
        end
        
        % if the click was inside the trace plot, check for whether an event is already selected
        if (eventCurrentlySelected == true)
            uialert(mainPanel, 'Please sort or delete the currently selected event.','');
            return;
        end
        eventCurrentlySelected = true;
        
        % find location of click in trace plot and determine nearest sample point
        pointLoc = tracePlot.CurrentPoint;
        traceIndex = dsearchn(currentWindow',pointLoc(1));
        
        % determine location of events that are already within the viewing window
        eventsInViewLogical = traceSamples(currentWindow,eventPlotLogicalCol) == 1;
        currentWindowEvents = currentWindow(eventsInViewLogical);
        eventsInView = traceSamples(currentWindowEvents,:);
        
        % check to see if mouse click location is on an event that has already been analyzed
        % if so, highlight the selected event
        if ~isempty(eventsInView)
            for viewedEvent = 1:size(eventsInView,1)
                tempThresholdTime = eventsInView(viewedEvent,traceTimeCol);
                tempPeakTime = eventsInView(viewedEvent,eventPlotEndCol);
                if currentWindow(traceIndex) >= tempThresholdTime...
                        && currentWindow(traceIndex) <= tempPeakTime
                    eventThresholdTime = tempThresholdTime;
                    eventPeakTime = tempPeakTime;
                    highlightEvent(eventThresholdTime);
                    return;
                end
            end
        end
        
        % set initial values for the event threshold and peak
        eventThresholdTime = currentWindow(traceIndex);
        eventPeakTime = eventThresholdTime;
        
        % determine the likely event threshold
        while ((trace_first_der(eventThresholdTime-1,traceValueCol) < -1.5) ||...
                (trace_first_der(eventThresholdTime-2,traceValueCol) < -1))
            eventThresholdTime = eventThresholdTime - 1;
        end
        traceSamples(eventThresholdTime,eventPlotLogicalCol) = 1;
        
        % determine the likely event peak
        while ((traceSamples(eventPeakTime,traceValueCol) > traceSamples(eventPeakTime+1,traceValueCol))...
                || (traceSamples(eventPeakTime,traceValueCol) > traceSamples(eventPeakTime+2,traceValueCol))...
                || (traceSamples(eventPeakTime,traceValueCol) > traceSamples(eventPeakTime+3,traceValueCol))...
                || (traceSamples(eventPeakTime,traceValueCol) > traceSamples(eventPeakTime+4,traceValueCol)))
            eventPeakTime = eventPeakTime + 1;
        end
        traceSamples(eventThresholdTime,eventPlotEndCol) = eventPeakTime;
        
        % create a location for the event in selectedEvents and plot the event
        eventIndex = length(selectedEvents);
        plotEvent(eventThresholdTime);
    end

    function navigateToEvent(~,event)
    % allows user to click on event in the data table and move to that event
    
        if (eventCurrentlySelected == true)
            uialert(mainPanel, 'Please sort or delete the selected event.','');
            return;
        end
        
        % determine which event was selected
        eventSelected = event.Indices;
        if ~(eventSelected(1) > 0)
            return;
        end
        eventIndex = table2array(event.Source.Data(eventSelected(1),1));
        eventThresholdTime = selectedEvents(eventIndex,eventTimeCol);
        
        % move view window and center it on selected event
        newCurrentWindowBegin = eventThresholdTime-floor(windowScope/2)+1;
        newCurrentWindowEnd = eventThresholdTime+floor(windowScope/2);
        currentWindow = newCurrentWindowBegin:newCurrentWindowEnd;
        if (currentWindow(end) > size(traceSamples,1))
            currentWindow = traceSamples(end-windowScope+1:end,traceTimeCol)';
        elseif (currentWindow(1) < 1)
            currentWindow = 1:ceil(windowScope);
        end
        plotLocation;
    end

    function keyPressListener(~,eventdata)
    % determine the key that was pressed and call the approptiate functiob
    
        keyPressed = eventdata.Key;
        if strcmpi(keyPressed,'a')
            addToFullDecayGroup;
        elseif strcmpi(keyPressed,'s')
            addToAmplitudeGroup;
        elseif strcmpi(keyPressed,'d')
            addToFrequencyGroup;
        elseif strcmpi(keyPressed,'z')
            previousWindow;
        elseif strcmpi(keyPressed,'x')
            nextWindow;
        elseif strcmpi(keyPressed,'q')
            backThreshold;
        elseif strcmpi(keyPressed,'w')
            forwardThreshold;
        elseif strcmpi(keyPressed,'e')
            backPeak;
        elseif strcmpi(keyPressed,'r')
            forwardPeak;
        elseif strcmpi(keyPressed,'f')
            deleteEvent;
        elseif strcmpi(keyPressed,'1')
            expandXView;
        elseif strcmpi(keyPressed,'2')
            shrinkXView;
        elseif strcmpi(keyPressed,'3')
            expandYView;
        elseif strcmpi(keyPressed,'4')
            shrinkYView;
        end
    end

%% plotting functions
    function plotEvent(eventTime)
    % plot the rise and decay phases of the selected event
    
        % determine values needed to plot rise and decay
        tempThresholdTime = traceSamples(eventTime,traceTimeCol);
        tempThresholdValue = traceSamples(tempThresholdTime,traceValueCol);
        tempPeakTime = traceSamples(eventTime,eventPlotEndCol);
        tempPeakValue = traceSamples(tempPeakTime,traceValueCol);
        valueAtDesiredDecay = tempPeakValue...
            +abs((1-(decayEndPercent/100))*(tempPeakValue-tempThresholdValue));
        decayTime = tempPeakTime+1;
        valueAtDecayTime = traceSamples(decayTime,traceValueCol);
        while valueAtDecayTime < valueAtDesiredDecay
            decayTime = decayTime + 1;
            valueAtDecayTime = traceSamples(decayTime,traceValueCol);
        end
        
        % generate and plot X and Y values for rise and decay
        meanWindowY = mean(traceSamples(currentWindow,traceValueCol));
        riseX = traceSamples(tempThresholdTime:tempPeakTime,traceTimeCol);
        riseY = traceSamples(tempThresholdTime:tempPeakTime,traceValueCol);
        riseYoffset = riseY - meanWindowY;       
        decayX = traceSamples(tempPeakTime:decayTime,traceTimeCol);
        decayY = traceSamples(tempPeakTime:decayTime,traceValueCol);
        decayYoffset = decayY - meanWindowY;
        hold(tracePlot, 'on');
        plot(tracePlot,riseX,riseYoffset,'Color',[1 0 1]);
        plot(tracePlot,decayX,decayYoffset,'Color',[0 1 0]);
        hold(tracePlot, 'off'); 
        
        % auto zoom to event if desired by user
        if (autoZoom == 1) && (eventCurrentlySelected == true)
            try
                yRangeLims = traceSamples(eventTime-50:eventTime+50,traceValueCol) - meanWindowY;
                yRange = range(traceSamples(eventTime-50:eventTime+50,traceValueCol));
            catch
                yRangeLims = traceSamples(eventTime-10:eventTime+10,traceValueCol) - meanWindowY;
                yRange = range(traceSamples(eventTime-10:eventTime+10,traceValueCol));
            end
            ylim(tracePlot,[min(yRangeLims)-0.25*yRange max(yRangeLims)+0.25*yRange]);
            yTemp = ylim(tracePlot);
            if yTemp(2)-yTemp(1) < 25
                ylim(tracePlot, ylim(tracePlot)*2);
            end
            xlim(tracePlot,[eventTime-200 eventTime+200]);
        end
    end

    function highlightEvent(eventTime)
    % hightlight an analyzed event that the user has selected
        
        % clear measured values for highlighted event
        [~,indexLoc] = ismember(eventTime,selectedEvents(:,eventTimeCol));
        selectedEvents(indexLoc,:) = NaN;
        eventIndex = indexLoc;

        % determine values needed to plot rise and decay
        eventThresholdTime = traceSamples(eventTime,traceTimeCol);
        eventThresholdValue = traceSamples(eventThresholdTime,traceValueCol);
        eventPeakTime = traceSamples(eventTime,eventPlotEndCol);
        eventPeakValue = traceSamples(eventPeakTime,traceValueCol);
        valueAtDesiredDecay = eventPeakValue...
            +abs((1-(decayStartPercent/100))*(eventPeakValue-eventThresholdValue));
        decayTime = eventPeakTime+1;
        valueAtDecayTime = traceSamples(decayTime,traceValueCol);
        while valueAtDecayTime < valueAtDesiredDecay
            decayTime = decayTime + 1;
            valueAtDecayTime = traceSamples(decayTime,traceValueCol);
        end
        
        % generate and plot X and Y values for rise and decay
        meanWindowY = mean(traceSamples(currentWindow,traceValueCol));
        riseX = traceSamples(eventThresholdTime:eventPeakTime,traceTimeCol);
        riseY = traceSamples(eventThresholdTime:eventPeakTime,traceValueCol);
        riseYoffset = riseY - meanWindowY;       
        decayX = traceSamples(eventPeakTime:decayTime,traceTimeCol);
        decayY = traceSamples(eventPeakTime:decayTime,traceValueCol);
        decayYoffset = decayY - meanWindowY;
        hold(tracePlot, 'on');
        plot(tracePlot,riseX,riseYoffset,'Color',[0 1 1]);
        plot(tracePlot,decayX,decayYoffset,'Color',[0 1 1]);
        hold(tracePlot, 'off'); 
        
        % auto zoom to event if desired by user
        if (autoZoom == 1) && (eventCurrentlySelected == true)
            try
                yRangeLims = traceSamples(eventTime-50:eventTime+50,traceValueCol) - meanWindowY;
                yRange = range(traceSamples(eventTime-50:eventTime+50,traceValueCol));
            catch
                yRangeLims = traceSamples(eventTime-10:eventTime+10,traceValueCol) - meanWindowY;
                yRange = range(traceSamples(eventTime-10:eventTime+10,traceValueCol));
            end
            ylim(tracePlot,[min(yRangeLims)-0.25*yRange max(yRangeLims)+0.25*yRange]);
            yTemp = ylim(tracePlot);
            if yTemp(2)-yTemp(1) < 25
                ylim(tracePlot, ylim(tracePlot)*2);
            end
            xlim(tracePlot,[eventTime-200 eventTime+200]);
        end
    end
        
    function plotLocation
    % plot the current view window, as well as any analyzed events that reside within
    
        % ignore call if no trace is present
        if isempty(traceSamples)
            return;
        end
        
        % generate and plot x and y values of trace
        traceX = traceSamples(currentWindow,traceTimeCol);
        traceY = traceSamples(currentWindow,traceValueCol);
        meanWindowY = mean(traceSamples(currentWindow,traceValueCol));
        traceYoffset = traceY - meanWindowY;
        plot(tracePlot,traceX,traceYoffset,'Color','black');
        axis(tracePlot,[currentWindow(1) currentWindow(end) yMin-yOffset yMax-yOffset]);
        
        % plot scale bar
        hold(tracePlot, 'on');
        digits = ceil(log10(windowScope));
        scaleNum = 10^(digits-2);
        xBegin = currentWindow(end) - ceil(0.1*windowScope);
        xVals = xBegin:xBegin+scaleNum;
        yRange = abs(yMax-yMin);
        yVals = repmat(yMin+ceil(0.1*yRange),length(xVals));
        plot(tracePlot,xVals,yVals,'Color','black');
        textX = xVals(1)+(floor(xVals(end)-xVals(1))/2);
        textY = yMin+ceil(0.15*yRange);
        text(tracePlot,textX,textY,sprintf('%d ms',scaleNum/samplesPerMilliSecond),...
            'HorizontalAlignment','center');
        hold(tracePlot, 'off');

        % determine location of previously analyzed events and display their event number
        eventsInViewLogical = traceSamples(currentWindow,eventPlotLogicalCol) == 1;
        for samplePoint = 1:size(eventsInViewLogical,1)
            if eventsInViewLogical(samplePoint) == 1
                plotEvent(currentWindow(samplePoint));
                [~,tempLoc] = ismember(currentWindow(samplePoint),selectedEvents(:,eventTimeCol));
                if tempLoc > 0
                    text(tracePlot,selectedEvents(tempLoc,eventTimeCol),5,num2str(tempLoc));
                end
            end
        end
        locationNum = num2str(round(currentWindow(end)*100/length(traceSamples),2));
        locationText = sprintf('%s%s',locationNum,'% through trace');
        locationX = currentWindow(end) - ceil(0.075*windowScope);
        locationY = yMin+ceil(0.025*yRange);
        text(tracePlot,locationX,locationY,locationText);
    end
     
    function displayEventData
    % update the table that displays measurements of events
    
        % ensure consistency of event record between selectedEvents and traceSamples
        dataConsistencyCheck;
        
        % pull relevant info from selectedEvents and generate table
        selectedEvents = sortrows(selectedEvents,eventTimeCol,'MissingPlacement','last');
        if ~isnan(selectedEvents(end-10,eventTimeCol))
            selectedEvents = [selectedEvents; nan(100,15)];
        end
        eventsForTableLogical = ~isnan(selectedEvents(:,eventTimeCol));
        selectedEventsSorted = selectedEvents(eventsForTableLogical,:);
        avgTraceCol = cell(size(selectedEventsSorted,1),1);
        avgTraceCol(:) = {char('')};
        avgTraceLogical = selectedEventsSorted(:,averageTraceLogicalCol) == 1;
        avgTraceCol(avgTraceLogical) = {char(sprintf('\x2022'))};
        avgTraceCol = string(avgTraceCol);
        fullCol = cell(size(selectedEventsSorted,1),1);
        fullCol(:) = {char('')};
        fullLogical = selectedEventsSorted(:,fullEventLogicalCol) == 1;
        fullCol(fullLogical) = {char(sprintf('\x2022'))};
        fullCol = string(fullCol);
        ampCol = cell(size(selectedEventsSorted,1),1);
        ampCol(:) = {char('')};
        ampLogical = selectedEventsSorted(:,amplitudeLogicalCol) == 1;
        ampCol(ampLogical) = {char(sprintf('\x2022'))};
        ampCol = string(ampCol);
        freqCol = cell(size(selectedEventsSorted,1),1);
        freqCol(:) = {char('')};
        freqLogical = selectedEventsSorted(:,frequencyLogicalCol) == 1;
        freqCol(freqLogical) = {char(sprintf('\x2022'))};
        freqCol = string(freqCol);
        dataTable = table((1:sum(eventsForTableLogical))',...
            avgTraceCol,fullCol,ampCol,freqCol,...            
            abs(selectedEventsSorted(:,amplitudeValueCol)),...
            selectedEventsSorted(:,riseTimeValueCol),...
            abs(selectedEventsSorted(:,riseSlopeValueCol)),...
            selectedEventsSorted(:,aucValueCol),...
            selectedEventsSorted(:,decayValueCol),...
            'VariableNames',...
                {'Event',...
                sprintf('Average\nTrace'),...
                sprintf('%s%s%s\nGroup','Full',' ','Event'),...
                sprintf('Amplitude\nGroup'),...
                sprintf('Frequency\nGroup'),...
                sprintf('Amplitude\n(pA)'),...
                sprintf('%s%s%s\n(ms)','Rise',' ','Time'),...
                sprintf('%s%s%s\n(pA/ms)','Rise',' ','Slope'),...
                sprintf('Area\n(fC)'),...
                sprintf('%s%s%s\n(ms)','Decay',' ','Time')});
       
        % sort and display table based on previous sorting parameters
        if ascendLogical == 0
            dataTable = sortrows(dataTable,sortedColumn,'descend');
        else
            dataTable = sortrows(dataTable,sortedColumn);
        end
        set(uit, 'Data', dataTable);
        set(uit, 'ColumnWidth','fit');
        style = uistyle('HorizontalAlignment','center');
        addStyle(uit,style);
    end

%% UI buttons
    function expandXView(~,~)
    % increase the x-range of the viewing window by a consistent factor
        
        if (eventCurrentlySelected == 1) && (autoZoom == 1)
            return;
        end
        viewScopeDiff = ceil((1.25*windowScope-windowScope)/2);        
        windowScope = windowScope*1.25;
        
        % check to see whether expanded window encompasses beginning or end of trace
        if windowScope >= length(traceSamples)
            currentWindow = 1:length(traceSamples);
            windowScope = length(traceSamples);
            uialert(mainPanel,'You are viewing the entire trace.','');
        elseif (currentWindow(1) <= viewScopeDiff)
            currentWindow(1:ceil(windowScope)) = 1:ceil(windowScope);
        elseif (currentWindow(end)+viewScopeDiff > size(traceSamples,1))
            currentWindow = traceSamples(end-windowScope+1:end,traceTimeCol)';
        else
            tempPre = currentWindow(1:viewScopeDiff) - viewScopeDiff;
            tempPost = currentWindow(end-viewScopeDiff:end) + viewScopeDiff;
            currentWindow = [tempPre currentWindow tempPost];
        end
        
        xSlider.Limits = xSlider.Limits*1.25;
        plotLocation;
    end

    function shrinkXView(~,~)
    % decrease the x-range of the viewing window by a consistent factor
        
        if (eventCurrentlySelected == 1) && (autoZoom == 1)
            return;
        end
        viewScopeDiff = ceil((windowScope - windowScope*0.8)/2);
        windowScope = windowScope*0.8;
    
        % prevent window from shrinking beyond a minimum size
        if windowScope < 10
            windowScope = windowScope*1.25;
            return;
        end
        currentWindow = currentWindow(viewScopeDiff:end-viewScopeDiff+1);
        
        xSlider.Limits = xSlider.Limits*0.8;
        plotLocation;
    end

    function expandYView(~,~)
    % increase the y-range of the viewing window by a consistent factor
    
        if (eventCurrentlySelected == 1) && (autoZoom == 1)
            return;
        end
        yMin = yMin*1.25;
        yMax = yMax*1.25;
        plotLocation;
        ySlider.Limits = ySlider.Limits*1.25;
    end

    function shrinkYView(~,~)
    % decrease the y-range of the viewing window by a consistent factor
    
        if (eventCurrentlySelected == 1) && (autoZoom == 1)
            return;
        end
        yMin = yMin*0.8;
        yMax = yMax*0.8;
        plotLocation;
        ySlider.Limits = ySlider.Limits*0.8;
    end
    
    function addToFullDecayGroup(~,~)
    % add event to group in which the full event is measured
    
        % ignore button click if no event is selected
        if eventCurrentlySelected == false
            uialert(mainPanel, 'Please select an event first.','');
            return;
        end
        
        % determine amplitude of selected event to check against noise threshold
        eventPeakValue = traceSamples(eventPeakTime,traceValueCol);
        eventThresholdValue = traceSamples(eventThresholdTime,traceValueCol);
        % don't check against threshold if updating event measurements
        if updatingLogical == false
            if abs(eventPeakValue - eventThresholdValue)  < noiseThreshold
                uialert(mainPanel, 'Event is below noise threshold.','');
                return;
            end
        end
        
        % update selectedEvents matrix and progress through event measurement
        selectedEvents(eventIndex,fullEventLogicalCol) = 1;    
%         if eventThresholdTime - preEventSamples < 1
%             uialert(mainPanel, 'Event is too close to beginning of trace','');
%             return;
%         elseif eventPeakTime + postEventSamples > length(traceSamples)
%             uialert(mainPanel, 'Event is too close to end of trace.','');
%             return;
%         end        
        
        selectedEvents(eventIndex,averageTraceLogicalCol) = 1;
        if updatingLogical == true
            selectedEvents(eventIndex,averageTraceLogicalCol) = averageTraceUpdate;          
        end
        addToAmplitudeGroup;
    end

    function addToAmplitudeGroup(~,~)
    % add event to group in which only the rise phase of an event is measured
    
        % ignore button click if no event is selected
        if eventCurrentlySelected == false
            uialert(mainPanel, 'Please select an event first.','');
            return;
        end

        % determine amplitude of selected event to check against noise threshold
        eventPeakValue = traceSamples(eventPeakTime,traceValueCol);
        eventThresholdValue = traceSamples(eventThresholdTime,traceValueCol);
        % don't check against threshold if updating event measurements
        if updatingLogical == false
            if abs(eventPeakValue - eventThresholdValue)  < noiseThreshold
                uialert(mainPanel, 'Event is below noise threshold.','');
                return;
            end
        end

        % update selectedEvents matrix and progress through event measurement
        selectedEvents(eventIndex,amplitudeLogicalCol) = 1;
        addToFrequencyGroup;
    end

    function addToFrequencyGroup(~,~)
    % add event to group in which only the rise phase of an event is measured
    
        % ignore button click if no event is selected
        if eventCurrentlySelected == false
            uialert(mainPanel, 'Please select an event first.','');
            return;
        end
        
        % determine amplitude of selected event to check against noise threshold
        eventPeakValue = traceSamples(eventPeakTime,traceValueCol);
        eventThresholdValue = traceSamples(eventThresholdTime,traceValueCol);
        % don't check against threshold if updating event measurements
        if updatingLogical == false
            if abs(eventPeakValue - eventThresholdValue)  < noiseThreshold
                uialert(mainPanel, 'Event is below noise threshold.','');
                return;
            end
        end    
        
        if selectedEvents(eventIndex,amplitudeLogicalCol) == 1
            selectedEvents(eventIndex,amplitudeValueCol) = eventPeakValue - eventThresholdValue;
        end
        calculateDecayValues;
        calculateRiseValues;
        
        % update selectedEvents matrix
        if selectedEvents(eventIndex,fullEventLogicalCol) == 1
            selectedEvents(eventIndex,aucValueCol) = abs(eventRiseAUC + eventDecayAUC);
        end
        
        selectedEvents(eventIndex,frequencyLogicalCol) = 1;
        selectedEvents(eventIndex,eventTimeCol) = eventThresholdTime;
        
        % reset event selection process, sort selectedEvents, and update GUI elements 
        eventCurrentlySelected = false;
        selectedEvents = sortrows(selectedEvents,eventTimeCol,'MissingPlacement','last');
        if updatingLogical == false
            updateSortCounts;
            displayEventData;
            plotLocation;
            plotOverlaidEvents;
        end
    end

    function deleteEvent(~,~)
    % delete events
        
        % check for whether an event in selected
        if eventCurrentlySelected == true 
        % delete only the selected event
            traceSamples(eventThresholdTime, eventPlotLogicalCol) = 0;
            traceSamples(eventThresholdTime, eventPlotEndCol) = nan;
            eventCurrentlySelected = false;
        else 
        % delete all events in view
            eventsInViewLogical = traceSamples(currentWindow,eventPlotLogicalCol) == 1;
            for samplePoint = 1:size(eventsInViewLogical,1)
                if eventsInViewLogical(samplePoint) == 1
                    traceSamples(currentWindow(samplePoint), eventPlotLogicalCol) = 0;
                    traceSamples(currentWindow(samplePoint), eventPlotEndCol) = nan;
                end
            end
        end
        
        % sort selectedEvents and update GUI elements
        selectedEvents = sortrows(selectedEvents,eventTimeCol,'MissingPlacement','last');
        displayEventData;
        updateSortCounts;
        plotLocation;  
        plotOverlaidEvents;
    end

    function backThreshold(~,~)
    % shift the threshold of the selected event by -1 sample points
    
        % ignore button click if no event is selected
        if eventCurrentlySelected == false
            uialert(mainPanel, 'Please select an event first.','');
            return;
        end
        
        % update values in trace record of event location
        traceSamples(eventThresholdTime,eventPlotLogicalCol) = 0;
        traceSamples(eventThresholdTime-1,eventPlotLogicalCol) = 1;
        traceSamples(eventThresholdTime-1,eventPlotEndCol) = traceSamples(eventThresholdTime,eventPlotEndCol);
        traceSamples(eventThresholdTime,eventPlotEndCol) = nan;
        eventThresholdTime = eventThresholdTime-1;
        
        % update GUI elements
        plotLocation;
        plotEvent(eventThresholdTime);
    end

    function forwardThreshold(~,~)
    % shift the threshold of the selected event by +1 sample points
    
        % ignore button click if no event is selected
        if eventCurrentlySelected == false
            uialert(mainPanel, 'Please select an event first.','');
            return;
        end
        
        % update values in trace record of event location
        traceSamples(eventThresholdTime,eventPlotLogicalCol) = 0;
        traceSamples(eventThresholdTime+1,eventPlotLogicalCol) = 1;
        traceSamples(eventThresholdTime+1,eventPlotEndCol) = traceSamples(eventThresholdTime,eventPlotEndCol);
        traceSamples(eventThresholdTime,eventPlotEndCol) = nan;
        eventThresholdTime = eventThresholdTime+1;
        
        % update GUI elements
        plotLocation;
        plotEvent(eventThresholdTime);
    end

    function backPeak(~,~)
    % shift the peak of the selected event by -1 sample points
    
        % ignore button click if no event is selected
        if eventCurrentlySelected == false
            uialert(mainPanel, 'Please select an event first.','');
            return;
        end
        
        % update values in trace record of event location
        traceSamples(eventThresholdTime,eventPlotEndCol) = traceSamples(eventThresholdTime,eventPlotEndCol)-1;
        eventPeakTime = traceSamples(eventThresholdTime,eventPlotEndCol);
        
        % update GUI elements
        plotLocation;
        plotEvent(eventThresholdTime);
    end

    function forwardPeak(~,~)
    % shift the peak of the selected event by +1 sample points
    
        % ignore button click if no event is selected
        if eventCurrentlySelected == false
            uialert(mainPanel, 'Please select an event first.','');
            return;
        end
        
        % update values in trace record of event location
        traceSamples(eventThresholdTime,eventPlotEndCol) = traceSamples(eventThresholdTime,eventPlotEndCol)+1;
        eventPeakTime = traceSamples(eventThresholdTime,eventPlotEndCol);
        
        % update GUI elements
        plotLocation;
        plotEvent(eventThresholdTime);
    end

    function previousWindow(~,~)
    % move the current view window to the previous window
    
        % ignore button click if an event is currently selected
        if (eventCurrentlySelected == true)
            uialert(mainPanel, 'Please sort or delete the selected event.','');
            return;
        end
        
        % check for whether the previous window contains the beginning of the trace
        if (currentWindow(1) <= windowScope)
            currentWindow = 1:ceil(windowScope);
        else
            currentWindow = currentWindow - ceil(windowScope);
        end
        
        % update GUI elements
        plotLocation;
    end

    function nextWindow(~,~)
    % move the current view window to the next window
        
        % ignore button click if an event is currently selected
        if (eventCurrentlySelected == true)
            uialert(mainPanel, 'Please sort or delete the selected event.','');
            return;
        end
        
        % check for whether the next window contains the end of the trace
        if (currentWindow(end)+windowScope >= size(traceSamples,1))
            currentWindow = traceSamples(end-length(currentWindow)+1:end,traceTimeCol)';
            uialert(mainPanel, 'End of trace.','');
        else
            currentWindow = currentWindow + ceil(windowScope);
        end
        
        % update GUI elements
        plotLocation;
    end

    function saveAnalysis(~,~)
    % save a .mat file containing relevant analysis data for later use
    
        % ignore button click if an event is currently selected
        if (eventCurrentlySelected == true)
            uialert(mainPanel, 'Please sort or delete the selected event.','');
            return;
        end
    
        % initiate progress bar
        d = uiprogressdlg(mainPanel,'Message','Saving...');
        
        % save relevant variables
        cd(rootDir);
        cd(savePath);
        saveName = strcat(cellName,'.mat');
        save(saveName, 'dataTable', 'currentWindow', 'selectedEvents', 'traceSamples',...
            'decayStartPercent','decayEndPercent','riseStartPercent','riseEndPercent',...
            'RMS','samplesPerMilliSecond','preEventSamples','postEventSamples','autoZoom');
        d.Value = 0.9;
        
        % update analysis file list on control tab of GUI
        matlist = dir('*.mat');
        matliststrings = string();
        for matIndex = 1:size(matlist,1)
            matliststrings(matIndex) = convertCharsToStrings(matlist(matIndex).name);
        end
        set(analysisList, 'Items', matliststrings);
        d.Value = 1;
    end

    function exitAnalysis(~,~)
    % exit the GUI
        decisionSave = uiconfirm(mainPanel,...
            'Save before exiting?','',...
            'Options',{'Yes','No'});
        if strcmp(decisionSave,'Yes')
            saveAnalysis;
        end
        delete(mainPanel);
    end

    function addFreqToAmp(~,~)
        % cycle through selectedEvents to re-sort all frequency events as
        % amplitude events
        
        % ignore button click if an event is currently selected
        if (eventCurrentlySelected == true)
            uialert(mainPanel, 'Please sort or delete the selected event.','');
            return;
        end
    
        d = uiprogressdlg(mainPanel,'Message','Updating...');
        for updateIndex = 1:sum(~isnan(selectedEvents(:,12)),1) 
            eventIndex = length(selectedEvents);
            eventCurrentlySelected = true;
            eventThresholdTime = selectedEvents(updateIndex,eventTimeCol);
            eventPeakTime = traceSamples(eventThresholdTime,eventPlotEndCol);
            if selectedEvents(updateIndex,fullEventLogicalCol) == 1
                continue;
            elseif selectedEvents(updateIndex,amplitudeLogicalCol) == 1
                continue;
            elseif selectedEvents(updateIndex,frequencyLogicalCol) == 1
                selectedEvents(updateIndex,:) = nan;
                addToAmplitudeGroup;
            end
            d.Value = updateIndex/sum(~isnan(selectedEvents(:,12)),1);
        end
        eventCurrentlySelected = false;
        plotLocation;
    end

    function addAmpToFull(~,~)
        % cycle through selectedEvents to re-sort all frequency events as
        % amplitude events
        
        % ignore button click if an event is currently selected
        if (eventCurrentlySelected == true)
            uialert(mainPanel, 'Please sort or delete the selected event.','');
            return;
        end
    
        d = uiprogressdlg(mainPanel,'Message','Updating...');
        for updateIndex = 1:sum(~isnan(selectedEvents(:,12)),1) 
            eventIndex = length(selectedEvents);
            eventCurrentlySelected = true;
            eventThresholdTime = selectedEvents(updateIndex,eventTimeCol);
            eventPeakTime = traceSamples(eventThresholdTime,eventPlotEndCol);
            if selectedEvents(updateIndex,fullEventLogicalCol) == 1
                continue;
            elseif selectedEvents(updateIndex,amplitudeLogicalCol) == 1
                selectedEvents(updateIndex,:) = nan;
                addToFullDecayGroup;
            end
            d.Value = updateIndex/sum(~isnan(selectedEvents(:,12)),1);
        end
        eventCurrentlySelected = false;
        plotLocation;
    end

    function plotOverlaidEvents(~,~)
    % plots raw events and scaled events for removal from average trace
        
        % ignore button click if an event is currently selected
        if (eventCurrentlySelected == true)
            uialert(mainPanel, 'Please sort or delete the selected event.','');
            return;
        end
    
        % clear plots and plot average trace
        cla(allTracePlot);
        cla(scaledTracePlot);
        plotAverageEvent;
        
        % generate graphics objects to allow interaction with traces in plot
        eventPlots = gobjects(1,size(selectedEvents,1));
        eventPlotsScaled = gobjects(1,size(selectedEvents,1));
        
        % generate and plot x and y values for event traces included in the average trace
        eventX = 0:1:totalSamples;
        hold(allTracePlot, 'on');
        for j = 1:size(selectedEvents,1)
            if (selectedEvents(j,averageTraceLogicalCol) ~= 1) 
                continue;
            end
            eventY = allTraces(:,j);
            eventPlots(j) = plot(allTracePlot,eventX,eventY,'Color',[0 0 0],'LineWidth',0.25);
            eventPlots(j).UserData = j;
            set(eventPlots(j), 'ButtonDownFcn', @rawTraceSelected);
        end
        xlim(allTracePlot,[0 totalSamples]);
        hold(allTracePlot, 'off');   
        
        % generate and plot x and y values for event traces included in the scaled average trace
        hold(scaledTracePlot, 'on');
        for j = 1:size(selectedEvents,1)
            if (selectedEvents(j,averageTraceLogicalCol) ~= 1) 
                continue;
            end
            eventY = allTraces(:,j)/selectedEvents(j,amplitudeValueCol)*-1;
            eventPlotsScaled(j) = plot(scaledTracePlot,eventX,eventY,'Color',[0 0 0],'LineWidth',0.25);
            eventPlotsScaled(j).UserData = j;
            set(eventPlotsScaled(j), 'ButtonDownFcn', @rawTraceSelected);
        end
        xlim(scaledTracePlot,[0 totalSamples]);
        hold(scaledTracePlot, 'off');      
    end
   
%% helper functions
    function measureRMS(~,~)
    % measures RMS at location determined by user
    
        % ignore if an event is currently selected
        if (eventCurrentlySelected == true)
            uialert(mainPanel, 'Please sort or delete the selected event before changing settings.','');
            rmsField.Value = RMS;
            return;
        end
    
        % check for plotted trace
        if isempty(traceSamples)
            uialert(mainPanel, 'RMS measurement requires a trace.','');
            return;
        end
        
        % zoom into a small window
        viewScopeOriginal = windowScope;
        windowScope = 256;
        currentWindowMidIndex = floor(length(currentWindow)/2);
        currentWindowMidValue = ceil(currentWindow(currentWindowMidIndex));
        halfView = floor(windowScope/2);
        currentWindow = currentWindowMidValue-halfView+1:currentWindowMidValue+halfView;
        plotLocation;
        
        % measure RMS
        tempRMS = round(...
            rms(traceSamples(currentWindow,traceValueCol)...
            -mean(traceSamples(currentWindow,traceValueCol))),3);
        
        % prompt user to confirm measurement and take appropriate action
        decisionRMS = uiconfirm(mainPanel,...
            sprintf('%s%g%s','Use ',tempRMS,' as the RMS?'),'',...
            'Options',{'Yes','No'});
        if strcmp(decisionRMS,'Yes') == 1
            RMS = tempRMS;
            rmsField.Value = RMS;
            rmsUpdate;
        end
        
        % return to original view
        windowScope = viewScopeOriginal;
        currentWindowMidIndex = floor(length(currentWindow)/2);
        currentWindowMidValue = ceil(currentWindow(currentWindowMidIndex));
        halfView = floor(windowScope/2);
        currentWindow = currentWindowMidValue-halfView+1:currentWindowMidValue+halfView;
        plotLocation;
    end

    function rmsUpdate(~,~)
    % remove evetns that fall below new noise threshold
    
        % ignore if an event is currently selected
        if (eventCurrentlySelected == true)
            uialert(mainPanel, 'Please sort or delete the selected event before changing settings.','');
            rmsField.Value = RMS;
            return;
        end
    
        % update displayed RMS and noise threshold values
        RMS = rmsField.Value;
        noiseThreshold = 3*RMS;
        cutoffText.Text = strcat("Noise Threshold: ",num2str(noiseThreshold)," pA");
        
        % prompt user to remove events and act on decision
        decisionRMS = uiconfirm(mainPanel,...
            'Remove events that fall below the new threshold?','',...
            'Options',{'Yes','No'});
        if strcmp(decisionRMS,'Yes')
            for checkIndex = 1:size(selectedEvents,1)
                if abs(selectedEvents(checkIndex,amplitudeValueCol)) < 3*RMS
                    eventThresholdTime = selectedEvents(checkIndex,eventTimeCol);
                    selectedEvents(checkIndex,:) = nan;
                    traceSamples(eventThresholdTime, eventPlotLogicalCol) = 0;
                    traceSamples(eventThresholdTime, eventPlotEndCol) = nan;
                end
            end
        end   
       
       % update GUI elements
       displayEventData;
       updateSortCounts;
       plotLocation;
    end
    
    function sortCallback(~,event)
    % saves information on data table sorting
        
        sortedColumn = event.InteractionDisplayColumn;
        ascendLogical = issortedrows(event.Source.DisplayData,sortedColumn,'ascend');
    end

    function populateLists(~,event)
    % add values to list boxes on the control tab
        
        % intialize lists and navigate to chosen experiment folder
        matliststrings = string();
        traceliststrings = string();
        chosenCell = directoryControl.Value;
        cd(rootDir);
        cd(chosenCell);
        previousFolder = event.PreviousValue;
        
        % generate list of analysis files
        matlist = dir('*.mat');
        for i = 1:size(matlist,1)
            matliststrings(i) = convertCharsToStrings(matlist(i).name);
        end
        
        % generate list of recording trace files
        filelist = dir('*.txt');
        for i = 1:(size(filelist,1))
            traceliststrings(i) = convertCharsToStrings(filelist(i).name);
        end
        traceliststrings = [string() traceliststrings];
        
        % update list contents in control tab list boxes
        set(mainTraceControl,'Items',traceliststrings);
        set(analysisList,'Items',matliststrings);
    end
    
    function calculateDecayValues
    % measure the decay phase of the selected event
        
        eventPeakValue = traceSamples(eventPeakTime,traceValueCol);
        eventThresholdValue = traceSamples(eventThresholdTime,traceValueCol);
        
        valueAtDesiredDecay = eventPeakValue...
            +abs((1-(decayEndPercent/100))*(eventPeakValue-eventThresholdValue));
        maxDecayIdx = eventPeakTime;
        while traceSamples(maxDecayIdx,traceValueCol) < valueAtDesiredDecay
            maxDecayIdx = maxDecayIdx + 1;
        end
        maxDecayTime = maxDecayIdx - eventPeakTime;
        
        % interpolate between sample points to generate fine-scale array of decay values
        for decIndex = 1:maxDecayTime
            tempArray = linspace(...
                traceSamples(eventPeakTime+(decIndex-1),traceValueCol)-eventThresholdValue,...
                traceSamples(eventPeakTime+decIndex,traceValueCol)-eventThresholdValue,101);
            decayArray(100*decIndex-99:100*decIndex,traceValueCol) = tempArray(2:101);
            tempArray = linspace(...
                traceSamples(eventPeakTime+(decIndex-1),traceTimeCol),...
                traceSamples(eventPeakTime+decIndex,traceTimeCol),101);
            decayArray(100*decIndex-99:100*decIndex,traceTimeCol) = tempArray(2:101);
        end
        
        % calculate time to 50 percent decay for use in half width calculation
        decayArrayIndex = 1;
        decayVal = decayArray(decayArrayIndex,1);
        try
            % in rare cases, due to membrane current fluctutions, it is not possible to iterate 
            % to the desired value
            while decayVal < (eventPeakValue-eventThresholdValue)/2
                decayArrayIndex = decayArrayIndex + 1;
                decayVal = decayArray(decayArrayIndex,1);
            end
        catch
            % in these rare cases, the event is measured for amplitude
            selectedEvents(eventIndex,fullEventLogicalCol) = nan;    
            selectedEvents(eventIndex,averageTraceLogicalCol) = nan;
            uialert(mainPanel,'A decay value could not be determined for an event','');
            return;
        end
        decay50Time = decayArrayIndex/100; 
        selectedEvents(eventIndex,decay50TimeCol) = eventPeakTime + decay50Time;
        
        % generate logical array for values that are in the selected range
        % of the decay
        decayLogical = zeros(size(decayArray,1),1);
        beginDecay = 1;
        while (decayArray(beginDecay,1)) < ((eventPeakValue-eventThresholdValue)*(decayStartPercent/100))
            beginDecay = beginDecay + 1;
        end
        endDecay = beginDecay;
        try
            % in rare cases, due to membrane current fluctutions, it is not possible to iterate 
            % to the desired value
            while (decayArray(endDecay,1)) < ((eventPeakValue-eventThresholdValue)*(decayEndPercent/100))
                endDecay = endDecay + 1;
            end
        catch
            % in these rare cases, the event is measured for amplitude
            selectedEvents(eventIndex,fullEventLogicalCol) = nan;    
            selectedEvents(eventIndex,averageTraceLogicalCol) = nan;
            uialert(mainPanel,'A decay value could not be determined for an event','');
            return;
        end
        decayLogical(beginDecay:endDecay) = 1;
        decayLogical = logical(decayLogical);
        decayArraySelected = decayArray(decayLogical);
        decayToPercentTime = length(decayArraySelected)/100;
               
        % calculate area under the curve from the peak to the desired decay percentage
        eventDecayAUC = (sum(decayArray(1:endDecay,1))/100)/samplesPerMilliSecond;
        if selectedEvents(eventIndex,fullEventLogicalCol) == 1
            selectedEvents(eventIndex,decayValueCol) = decayToPercentTime/samplesPerMilliSecond;
        end
        return;
    end    
    
    function calculateRiseValues
    % measure the rise phase of the selected event

        eventThresholdValue = traceSamples(eventThresholdTime,traceValueCol);
               
        % interpolate between sample points to generate fine-scale array of rise values
        for riseIndex = 1:(eventPeakTime - eventThresholdTime)
            tempArray = linspace(...
                traceSamples(eventThresholdTime+(riseIndex-1),traceValueCol)-eventThresholdValue,...
                traceSamples(eventThresholdTime+riseIndex,traceValueCol)-eventThresholdValue,101);
            riseArray(100*riseIndex-99:100*riseIndex,traceValueCol) = tempArray(2:101);
            tempArray = linspace(...
                traceSamples(eventThresholdTime+(riseIndex-1),traceTimeCol),...
                traceSamples(eventThresholdTime+riseIndex,traceTimeCol),101);
            riseArray(100*riseIndex-99:100*riseIndex,traceTimeCol) = tempArray(2:101);
        end
        
        % calculate area under the curve from the rise to the peak
        eventRiseAUC = (sum(riseArray(:,1))/100)/samplesPerMilliSecond;
        
        % calculate time to 50 percent rise for use in half width calculation
        riseIndex = 1;
        while riseArray(riseIndex,1) > (riseArray(end,1)/2)
            riseIndex = riseIndex + 1;
        end
        selectedEvents(eventIndex,rise50TimeCol) = riseArray(riseIndex,2);
        if selectedEvents(eventIndex,fullEventLogicalCol) == 1
            selectedEvents(eventIndex,halfWidthValueCol) =...
                (selectedEvents(eventIndex,decay50TimeCol)-selectedEvents(eventIndex,rise50TimeCol))...
                /samplesPerMilliSecond;
        end
                
        % generate logical array for values that are in the selected range of the rise
        riseLogical = zeros(size(riseArray,1),1);
        beginRise = 1;
        endRise = size(riseArray,1);
        while (riseArray(beginRise,1)) > (selectedEvents(eventIndex,amplitudeValueCol)*(riseStartPercent/100))
            beginRise = beginRise + 1;
        end
        while (riseArray(endRise,1)) < (selectedEvents(eventIndex,amplitudeValueCol)*(riseEndPercent/100))
            endRise = endRise - 1;
        end
        riseLogical(beginRise:endRise) = 1;
        riseLogical = logical(riseLogical);
        
        % create selected rise array
        riseArraySelected = riseArray(riseLogical,:);
        
        % update measurements in selectedEvents
        if selectedEvents(eventIndex,amplitudeLogicalCol) == 1
            selectedEvents(eventIndex,riseSlopeValueCol) =...
                (riseArraySelected(end,1)-riseArraySelected(1,1))...
                /((size(riseArraySelected,1)/100)/samplesPerMilliSecond);
            selectedEvents(eventIndex,riseTimeValueCol) =...
                (riseArraySelected(end,2)-riseArraySelected(1,2))/samplesPerMilliSecond; 
        end
        return;
    end

    function updateMeasurements
    % cycle through selectedEvents to re-analyze events with different settings
        
        updatingLogical = true;
    
        % ignore button click if an event is currently selected
        if (eventCurrentlySelected == true)
            uialert(mainPanel, 'Please sort or delete the selected event.','');
            return;
        end
    
        d = uiprogressdlg(mainPanel,'Message','Updating...');
        for updateIndex = 1:sum(~isnan(selectedEvents(:,12)),1) 
            eventIndex = length(selectedEvents);
            eventCurrentlySelected = true;
            eventThresholdTime = selectedEvents(updateIndex,eventTimeCol);
            eventPeakTime = traceSamples(eventThresholdTime,eventPlotEndCol);
            averageTraceUpdate = selectedEvents(updateIndex,averageTraceLogicalCol);
            if selectedEvents(updateIndex,fullEventLogicalCol) == 1
                selectedEvents(updateIndex,:) = nan;
                addToFullDecayGroup;
            elseif selectedEvents(updateIndex,amplitudeLogicalCol) == 1
                selectedEvents(updateIndex,:) = nan;
                addToAmplitudeGroup;
            elseif selectedEvents(updateIndex,frequencyLogicalCol) == 1
                selectedEvents(updateIndex,:) = nan;
                addToFrequencyGroup;
            end
            d.Value = updateIndex/sum(~isnan(selectedEvents(:,12)),1);
        end
        updatingLogical = false;
        updateSortCounts;
        displayEventData;
        plotLocation;
        plotOverlaidEvents;
    end

    function fieldUpdate(~,~)
    % updates various analysis parameters based on user input and updates trace plot
        
        % ignore if an event is currently selected
        if (eventCurrentlySelected == true)
            uialert(mainPanel, 'Please sort or delete the selected event before changing settings.','');
            samplingField.Value = samplesPerMilliSecond;
            decayStartField.Value = decayStartPercent;
            return;
        end
        samplesPerMilliSecond = samplingField.Value;
        decayStartPercent = decayStartField.Value;
        decayEndPercent = decayEndField.Value;
        riseStartPercent = riseStartField.Value;
        riseEndPercent = riseEndField.Value;
        updateMeasurements;
        plotLocation;
    end

    function zoomChange(~,~)
    % updates auto zoom functionality
    
        % ignore if an event is currently selected
        if (eventCurrentlySelected == true)
            uialert(mainPanel, 'Please sort or delete the selected event before changing settings.','');
            zoomCheck.Value = autoZoom;  
            return;
        end
        autoZoom = zoomCheck.Value;
    end

    function sampleNumberUpdate(~,~)
    % updates sample number values based on user input
    % replots overlaid events if sample number is changed
    
        % ignore if an event is currently selected
        if (eventCurrentlySelected == true)
            uialert(mainPanel, 'Please sort or delete the selected event before changing settings.','');
            preEventField.Value = preEventSamples;
            postEventField.Value = postEventSamples;
            return;
        end
    
        replotLogical = false;
        if (preEventSamples ~= preEventField.Value) || (postEventSamples ~= postEventField.Value)
            replotLogical = true;
        end
        preEventSamples = preEventField.Value;
        postEventSamples = postEventField.Value;
        if replotLogical == true
            plotOverlaidEvents;
        end
    end

    function alignmentChange(~,event)
        traceAlignment = event.NewValue.Text;
        plotOverlaidEvents;
    end
     
    function evaluateCurrentPlotTab(~,~)
    % determine the plot tab that is active
    % turn keyboard control and event selection on or off depending on the tab
    
        tempTab = get(plotTabGroup, 'SelectedTab');
        if strcmp(tempTab.Title,'Average Event')
            set(mainPanel,'WindowButtonDownFcn','');
            set(mainPanel, 'KeyPressFcn', '');
        elseif strcmp(tempTab.Title,'Trace')
            set(mainPanel,'WindowButtonDownFcn',@selectEvent);
            set(mainPanel, 'KeyPressFcn', @keyPressListener);
        end
    end

    function rawTraceSelected(event,~)
    % allows user to graphically remove events from the average trace
        
        % get event number and make the event visible against all others
        eventNum = event.UserData;
        set(eventPlots(eventNum), 'Color', 'red');
        set(eventPlots(eventNum), 'LineWidth', 2);
        set(eventPlots(eventNum), 'ZData', 0:totalSamples);
        set(eventPlotsScaled(eventNum), 'Color', 'red');
        set(eventPlotsScaled(eventNum), 'LineWidth', 2);
        set(eventPlotsScaled(eventNum), 'ZData', 0:totalSamples);
        
        % prompt user to remove event and act on response
        traceDecision = uiconfirm(mainPanel,...
            'Remove the selected event from the average trace?','',...
            'Options',{'Yes','No'});
        if strcmp(traceDecision, 'Yes') == 1
        % remove event
            selectedEvents(eventNum,averageTraceLogicalCol) = nan;
            delete(eventPlots(eventNum));
            delete(eventPlotsScaled(eventNum));
            plotAverageEvent;
        else
        % return event to original state
            set(eventPlots(eventNum), 'Color', 'black');
            set(eventPlots(eventNum), 'LineWidth', 0.25);
            set(eventPlots(eventNum), 'ZData', []);
            set(eventPlotsScaled(eventNum), 'Color', 'black');
            set(eventPlotsScaled(eventNum), 'LineWidth', 0.25);
            set(eventPlotsScaled(eventNum), 'ZData', []);
        end
        updateSortCounts
    end

    function plotAverageEvent
    % plots the average event trace
    
        if sum(~isnan(selectedEvents)) == 0
            return;
        end
    
        % clear the average trace plot and initialize key variables
        cla(averageTracePlot);
        allTraces = [];
        totalSamples = preEventSamples + postEventSamples;
                
        % generate a matrix containing all event traces that will be included in the average
        if strcmp(traceAlignment,'Align By Threshold')
            for j = 1:size(selectedEvents,1)
                if isnan(selectedEvents(j,eventTimeCol)) 
                    continue;
                end
                thresholdIndex = selectedEvents(j,eventTimeCol);
                thresholdValue = traceSamples(thresholdIndex,traceValueCol);
                tempTraceBeginIndex = thresholdIndex-preEventSamples;
                tempTraceEndIndex = thresholdIndex+postEventSamples;
                if tempTraceBeginIndex < 1
                    tempTrace = traceSamples(1:tempTraceEndIndex,1);
                    tempTrace = [nan((1-tempTraceBeginIndex),1); tempTrace];
                elseif tempTraceEndIndex > length(traceSamples)
                    tempTrace = traceSamples(tempTraceBeginIndex:length(traceSamples),1);
                    tempTrace = [tempTrace; nan((tempTraceEndIndex-length(traceSamples)),1)];
                else
                    tempTrace = traceSamples(tempTraceBeginIndex:tempTraceEndIndex,1);
                end
                tempTraceOffset = tempTrace - thresholdValue;
                allTraces = [allTraces tempTraceOffset];
            end
        elseif strcmp(traceAlignment,'Align By Peak')
            for j = 1:size(selectedEvents,1)
                if isnan(selectedEvents(j,eventTimeCol)) 
                    continue;
                end
                thresholdIndex = selectedEvents(j,eventTimeCol);
                thresholdValue = traceSamples(thresholdIndex,traceValueCol);
                peakIndex = traceSamples(thresholdIndex,eventPlotEndCol);
                tempTraceBeginIndex = peakIndex-preEventSamples;
                tempTraceEndIndex = peakIndex+postEventSamples;
                if tempTraceBeginIndex < 1
                    tempTrace = traceSamples(1:tempTraceEndIndex,1);
                    tempTrace = [nan((1-tempTraceBeginIndex),1); tempTrace];
                elseif tempTraceEndIndex > length(traceSamples)
                    tempTrace = traceSamples(tempTraceBeginIndex:length(traceSamples),1);
                    tempTrace = [tempTrace; nan((tempTraceEndIndex-length(traceSamples)),1)];
                else
                    tempTrace = traceSamples(tempTraceBeginIndex:tempTraceEndIndex,1);
                end
                tempTraceOffset = tempTrace - thresholdValue;
                allTraces = [allTraces tempTraceOffset];
            end
        end
        
        % calculate and plot the X and Y values for the average event trace
        averageTrace = mean(allTraces(:,selectedEvents(:,averageTraceLogicalCol) == 1),2);
        averageTraceX = 0:1:totalSamples;
        plot(averageTracePlot,averageTraceX,averageTrace,'Color',[0 0 0],'LineWidth',2);
        xlim(averageTracePlot,[0 totalSamples]);
    end        

    function updateSortCounts
    % update labels on GUI main panel that display the # of events in each analysis group
        
        set(avgCount,'Text',...
            sprintf('%s%i','# in Average Trace: ',nansum(selectedEvents(:,averageTraceLogicalCol))));
        set(fullCount,'Text',...
            sprintf('%s%i','# in Full Event: ',nansum(selectedEvents(:,fullEventLogicalCol))));
        set(ampCount,'Text',...
            sprintf('%s%i','# in Amplitude: ',nansum(selectedEvents(:,amplitudeLogicalCol))));
        set(freqCount,'Text',...
            sprintf('%s%i','# in Frequency: ',nansum(selectedEvents(:,frequencyLogicalCol))));
    end

    function dataConsistencyCheck
    % checks selectedEvents against the record of events in traceSamples
    % non-existant events are removed from selectedEvents
    
        selectedEvents = sortrows(selectedEvents,eventTimeCol,'MissingPlacement','last');
        for i = 1:size(selectedEvents,1)
            if ~isnan(selectedEvents(i,eventTimeCol))...
                    && traceSamples(selectedEvents(i,eventTimeCol),eventPlotLogicalCol) ~= 1
                selectedEvents(i,:) = nan;
            end
            if (i > 1) && (selectedEvents(i,eventTimeCol) == selectedEvents(i-1,eventTimeCol))         
                selectedEvents(i,:) = nan;
            end
        end
    end

%% slider control functions
    function ySliderFunc(~,event)
    % controls the function of the y slider
        yOffset = event.Value;
        plotLocation;
    end

    function xSliderFunc(~,event)
    % controls the function of the x slider
    
        xOffset = round(event.Value-event.PreviousValue);
        if (currentWindow(1) - xOffset) < 1
            currentWindow = 1:ceil(windowScope);
            uialert(mainPanel, 'Beginning of trace.','');
            xSlider.Value = 0;
        elseif (currentWindow(end) - xOffset) >= size(traceSamples,1)
            currentWindow = traceSamples(end-length(currentWindow)+1:end,traceTimeCol)';
            uialert(mainPanel, 'End of trace.','');
            xSlider.Value = 0;
        else
            currentWindow = currentWindow - xOffset;
        end
        plotLocation;
    end

%% clean up
    close ALL FORCE
    cd(rootDir);
%     [~,~,~,~] = exportData('output',true,'exportedGroup',exportGroup,'numberOfEvents',exportNum,'frequencyCalculation',freqCalcPref);
end
