function wholeCellAnalysis

    mainPanel = uifigure;
    message = 'What would you like to do?';
    choices = {'Analyze Traces','Batch Export','Cancel'};
    uiconfirm(mainPanel,message,'','Options',choices,...
        'CancelOption',3,'CloseFcn',@programChoiceFunc);

    function programChoiceFunc(~,event)
        close ALL FORCE;
        if event.SelectedOptionIndex == 1
            analyzeTraces;
        elseif event.SelectedOptionIndex == 2
            exportDataGUI;
        else
            return;
        end
    end

end
