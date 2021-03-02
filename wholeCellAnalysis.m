function wholeCellAnalysis

    mainPanel = uifigure;
    message = 'What would you like to do?';
    choices = {'Analyze Traces','Batch Export','Cancel'};
    uiconfirm(mainPanel,message,'','Options',choices,...
        'CancelOption',3,'CloseFcn',@programChoiceFunc);

    %% check for Matlab version 2020b or newer
    version = ver('Matlab');
    yearDif = str2double(version.Release(3:6)) - 2020;
    releaseDif = (version.Release(7)) - 'b';
    % check for a release year before 2020
    % negative values of yearDif indicate 2019 or earlier
    % if release year is 2020 check for a release letter of 'b'
    % a negative value of releaseDif indicates release letter 'a'
    if yearDif < 0
        message = sprintf('%s%s%','Please update Matlab to release ',version.Release,' or newer to use this app.'); 
        uialert(mainPanel, message);
        return;
    elseif (yearDif == 0) && (releaseDif < 0)
        message = sprintf('%s%s%','Please update Matlab to release ',version.Release,' or newer to use this app.'); 
        uialert(mainPanel, message);
        return;
    end
    
    %% check for needed toolboxes
    if ~license('test','Signal_Toolbox')
        uialert(mainPanel, 'Please install the Statistics and Machine Learning Toolbox to use this app.');
        return;
    end
    if ~license('test','Statistics_Toolbox')
        uialert(mainPanel, 'Please install the Signal Processing Toolbox to use this app.');
        return;
    end
    if ~license('test','Curve_Fitting_Toolbox')
        uialert(mainPanel, 'Please install the Curve Fitting Toolbox to use this app.');
        return;
    end
    
    %% choose action
    function programChoiceFunc(~,event)
        close ALL FORCE;
        if event.SelectedOptionIndex == 1
            analyzeTraces;
        elseif event.SelectedOptionIndex == 2
            exportGUI;
        else
            return;
        end
    end

end
