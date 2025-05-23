classdef WinampEqualizer < matlab.apps.AppBase

    % Properties that correspond to app components
    properties (Access = public)
        UIFigure                   matlab.ui.Figure
        LoadButton                 matlab.ui.control.Button
        ApplyFilterButton          matlab.ui.control.Button
        SaveButton                 matlab.ui.control.Button
        FilenameEditFieldLabel     matlab.ui.control.Label
        FilenameEditField          matlab.ui.control.EditField
        OutputSampleRateEditFieldLabel matlab.ui.control.Label
        OutputSampleRateEditField  matlab.ui.control.NumericEditField
        FilterTypeDropDownLabel    matlab.ui.control.Label
        FilterTypeDropDown         matlab.ui.control.DropDown
        FilterOrderEditFieldLabel  matlab.ui.control.Label
        FilterOrderEditField       matlab.ui.control.NumericEditField
        GainsPanel                 matlab.ui.container.Panel
        GainsSliders               matlab.ui.control.Slider
        GainsSliderLabels          matlab.ui.control.Label
        OriginalAxes               matlab.ui.control.UIAxes
        FilteredAxes               matlab.ui.control.UIAxes
        StatusText                 matlab.ui.control.Label
    end

    properties (Access = private)
        OriginalAudio   % Loaded audio data
        SampleRate      % Original sample rate
        FilteredAudio   % Filtered audio result
        TotalAudio      % Summed filtered output
        Gains           % Gains for each frequency band in dB
        FreqRanges = [0, 200, 400, 800, 1200, 3000, 6000, 12000, 15000, 20000]
    end

    % Callbacks that handle component events
    methods (Access = private)

        % Button pushed function: LoadButton
        function LoadButtonPushed(app, event)
            filename = strtrim(app.FilenameEditField.Value);
            if isempty(filename)
                app.StatusText.Text = 'Please enter an audio filename.';
                return;
            end
            try
                [audio, fs] = audioread(filename);
                app.OriginalAudio = audio;
                app.SampleRate = fs;
                app.OutputSampleRateEditField.Value = fs;
                app.StatusText.Text = sprintf('Loaded "%s" (Sample Rate: %d Hz)', filename, fs);
                % Plot original audio
                plot(app.OriginalAxes, audio);
                title(app.OriginalAxes, 'Original Signal');
                xlabel(app.OriginalAxes, 'Samples');
                ylabel(app.OriginalAxes, 'Amplitude');
                grid(app.OriginalAxes,'on');
                % Clear Filtered plot
                cla(app.FilteredAxes);
            catch ME
                app.StatusText.Text = sprintf('Error loading file: %s', ME.message);
            end
        end

        % Apply filter button pushed
        function ApplyFilterButtonPushed(app, event)
            if isempty(app.OriginalAudio)
                app.StatusText.Text = 'No audio loaded.';
                return;
            end
            
            % Read user gains values from sliders (convert from dB to linear gain)
            dBgains = zeros(1, 9);
            for i = 1:9
                dBgains(i) = app.GainsSliders(i).Value;
            end
            app.Gains = dBgains;
            linearGains = 10.^(dBgains/20);
            
            % Manage output sampling rate
            O_Sample_R = app.OutputSampleRateEditField.Value;
            origFs = app.SampleRate;
            audio = app.OriginalAudio;
            
            % Resample if needed
            if O_Sample_R ~= origFs
                audio = resample(audio, O_Sample_R, origFs);
            end
            
            half_Sam_Rate = O_Sample_R/2;
            
            Total = zeros(size(audio));
            
            filterType = app.FilterTypeDropDown.Value;
            Order = app.FilterOrderEditField.Value;
            
            % Filtering process for each freq band
            try
                switch filterType
                    case 'IIR'
                        for i=1:9
                            if i == 1
                                Wn = app.FreqRanges(i+1)/half_Sam_Rate;
                                [b,a] = butter(Order, Wn);
                            else
                                Wn = [app.FreqRanges(i) app.FreqRanges(i+1)]/half_Sam_Rate;
                                [b,a] = butter(Order, Wn);
                            end
                            filtered = filter(b,a, audio) * linearGains(i);
                            Total = Total + filtered;
                            
                            % Plot magnitude and phase response for each band
                            [H, f] = freqz(b,a,512, O_Sample_R);
                            figure('Name',sprintf('IIR Filter %d-%d Hz Response', app.FreqRanges(i), app.FreqRanges(i+1)));
                            subplot(4,1,1);
                            plot(f, abs(H));
                            grid on;
                            title(sprintf('Magnitude Response (%d-%d Hz)', app.FreqRanges(i), app.FreqRanges(i+1)));
                            xlabel('Frequency (Hz)');
                            ylabel('|H(f)|');
                            
                            subplot(4,1,2);
                            plot(f, angle(H)*180/pi);
                            grid on;
                            title('Phase Response (Degrees)');
                            xlabel('Frequency (Hz)');
                            ylabel('Phase (deg)');
                            xlim([0 O_Sample_R/10]);
                            
                            subplot(4,1,3);
                            impulse(tf(b,a));
                            title('Impulse Response');
                            grid on;
                            
                            subplot(4,1,4);
                            step(tf(b,a));
                            title('Step Response');
                            grid on;
                        end
                        
                    case 'FIR'
                        for i=1:9
                            if i == 1
                                Wn = app.FreqRanges(i+1)/half_Sam_Rate;
                                b = fir1(Order, Wn);
                            else
                                Wn = [app.FreqRanges(i) app.FreqRanges(i+1)]/half_Sam_Rate;
                                b = fir1(Order, Wn);
                            end
                            filtered = filter(b, 1, audio) * linearGains(i);
                            Total = Total + filtered;
                            
                            % Plot magnitude and phase response for each band
                            [H, f] = freqz(b,1,512,O_Sample_R);
                            figure('Name',sprintf('FIR Filter %d-%d Hz Response', app.FreqRanges(i), app.FreqRanges(i+1)));
                            subplot(4,1,1);
                            plot(f, abs(H));
                            grid on;
                            title(sprintf('Magnitude Response (%d-%d Hz)', app.FreqRanges(i), app.FreqRanges(i+1)));
                            xlabel('Frequency (Hz)');
                            ylabel('|H(f)|');
                            
                            subplot(4,1,2);
                            plot(f, angle(H)*180/pi);
                            grid on;
                            title('Phase Response (Degrees)');
                            xlabel('Frequency (Hz)');
                            ylabel('Phase (deg)');
                            xlim([0 O_Sample_R/10]);
                            
                            subplot(4,1,3);
                            impz(b,1);
                            title('Impulse Response');
                            grid on;
                            
                            subplot(4,1,4);
                            stepz(b,1);
                            title('Step Response');
                            grid on;
                        end
                end
            catch ME
                app.StatusText.Text = ['Filtering error: ' ME.message];
                return;
            end
            
            % Normalize output signal
            Total = Total / max(abs(Total));
            app.FilteredAudio = Total;
            app.TotalAudio = Total;
            
            % Plot filtered audio
            plot(app.FilteredAxes, Total);
            title(app.FilteredAxes, 'Filtered Signal');
            xlabel(app.FilteredAxes, 'Samples');
            ylabel(app.FilteredAxes, 'Amplitude');
            grid(app.FilteredAxes,'on');
            
            app.StatusText.Text = 'Filtering complete.';
        end

        % Save Button pushed
        function SaveButtonPushed(app, event)
            if isempty(app.FilteredAudio)
                app.StatusText.Text = 'No filtered audio to save.';
                return;
            end
            filename = strtrim(app.FilenameEditField.Value);
            if isempty(filename)
                app.StatusText.Text = 'Enter original filename to base save name on.';
                return;
            end
            outputFilename = sprintf('filtered_%s.wav', filename);
            try
                audiowrite(outputFilename, app.FilteredAudio, app.OutputSampleRateEditField.Value);
                app.StatusText.Text = sprintf('Filtered audio saved as "%s".', outputFilename);
            catch ME
                app.StatusText.Text = sprintf('Error saving file: %s', ME.message);
            end
        end

        % Create slider labels and sliders dynamically
        function createGainSliders(app)
            % Delete old sliders/labels if any
            if ~isempty(app.GainsSliders)
                delete(app.GainsSliders);
                delete(app.GainsSliderLabels);
            end
            nBands = length(app.FreqRanges)-1;
            app.GainsSliders = gobjects(1, nBands);
            app.GainsSliderLabels = gobjects(1, nBands);
            panelWidth = app.GainsPanel.Position(3);
            panelHeight = app.GainsPanel.Position(4);
            % Layout parameters
            sliderHeight = 3;
            sliderWidth = 250;
            labelWidth = 100;
            spacingY = 40;
            startY = panelHeight - 50;
            for i=1:nBands
                yPos = startY - (i-1)*spacingY;
                % Label
                app.GainsSliderLabels(i) = uilabel(app.GainsPanel);
                app.GainsSliderLabels(i).Position = [10 yPos labelWidth 22];
                app.GainsSliderLabels(i).Text = sprintf('%d - %d Hz (dB):', app.FreqRanges(i), app.FreqRanges(i+1));
                % Slider
                app.GainsSliders(i) = uislider(app.GainsPanel);
                app.GainsSliders(i).Position = [labelWidth+20 yPos+10 sliderWidth sliderHeight];
                app.GainsSliders(i).Limits = [-20 20];
                app.GainsSliders(i).Value = 0;
                app.GainsSliders(i).MajorTicks = [-20 -10 0 10 20];
                app.GainsSliders(i).MinorTicks = [];
            end
        end

    end

    % Component initialization
    methods (Access = private)

        % Create UIFigure and components
        function createComponents(app)

            % Create UIFigure and hide until all components created
            app.UIFigure = uifigure('Visible', 'off');
            app.UIFigure.Position = [100 100 900 550];
            app.UIFigure.Name = 'WinampEqualizer';

            % Filename Label
            app.FilenameEditFieldLabel = uilabel(app.UIFigure);
            app.FilenameEditFieldLabel.HorizontalAlignment = 'right';
            app.FilenameEditFieldLabel.Position = [30 495 100 22];
            app.FilenameEditFieldLabel.Text = 'Audio Filename:';

            % Filename Edit Field
            app.FilenameEditField = uieditfield(app.UIFigure, 'text');
            app.FilenameEditField.Position = [140 495 200 22];
            app.FilenameEditField.Placeholder = 'e.g. song.wav';

            % Load Button
            app.LoadButton = uibutton(app.UIFigure, 'push');
            app.LoadButton.Position = [360 493 100 26];
            app.LoadButton.Text = 'Load Audio';
            app.LoadButton.ButtonPushedFcn = createCallbackFcn(app, @LoadButtonPushed, true);

            % Output Sample Rate Label
            app.OutputSampleRateEditFieldLabel = uilabel(app.UIFigure);
            app.OutputSampleRateEditFieldLabel.HorizontalAlignment = 'right';
            app.OutputSampleRateEditFieldLabel.Position = [30 455 100 22];
            app.OutputSampleRateEditFieldLabel.Text = 'Output Sample Rate:';

            % Output Sample Rate Numeric Edit
            app.OutputSampleRateEditField = uieditfield(app.UIFigure,'numeric');
            app.OutputSampleRateEditField.Position = [140 455 120 22];
            app.OutputSampleRateEditField.Limits = [8000 192000];
            app.OutputSampleRateEditField.Value = 44100;

            % Filter Type Label
            app.FilterTypeDropDownLabel = uilabel(app.UIFigure);
            app.FilterTypeDropDownLabel.HorizontalAlignment = 'right';
            app.FilterTypeDropDownLabel.Position = [300 455 70 22];
            app.FilterTypeDropDownLabel.Text = 'Filter Type:';

            % Filter Type Drop Down
            app.FilterTypeDropDown = uidropdown(app.UIFigure);
            app.FilterTypeDropDown.Position = [380 455 80 22];
            app.FilterTypeDropDown.Items = {'IIR', 'FIR'};
            app.FilterTypeDropDown.Value = 'IIR';

            % Filter Order Label
            app.FilterOrderEditFieldLabel = uilabel(app.UIFigure);
            app.FilterOrderEditFieldLabel.HorizontalAlignment = 'right';
            app.FilterOrderEditFieldLabel.Position = [480 455 70 22];
            app.FilterOrderEditFieldLabel.Text = 'Filter Order:';

            % Filter Order Numeric Edit
            app.FilterOrderEditField = uieditfield(app.UIFigure,'numeric');
            app.FilterOrderEditField.Position = [560 455 60 22];
            app.FilterOrderEditField.Limits = [1 20];
            app.FilterOrderEditField.Value = 4;

            % Apply Filter Button
            app.ApplyFilterButton = uibutton(app.UIFigure, 'push');
            app.ApplyFilterButton.Position = [650 453 110 26];
            app.ApplyFilterButton.Text = 'Apply Filter';
            app.ApplyFilterButton.ButtonPushedFcn = createCallbackFcn(app, @ApplyFilterButtonPushed, true);

            % Save Button
            app.SaveButton = uibutton(app.UIFigure, 'push');
            app.SaveButton.Position = [780 453 100 26];
            app.SaveButton.Text = 'Save Filtered Audio';
            app.SaveButton.ButtonPushedFcn = createCallbackFcn(app, @SaveButtonPushed, true);

            % Gains Panel - will hold sliders dynamically
            app.GainsPanel = uipanel(app.UIFigure);
            app.GainsPanel.Title = 'Frequency Band Gains (dB)';
            app.GainsPanel.Position = [20 60 400 380];

            % Create gain sliders dynamically
            app.createGainSliders()

            % Original Signal Axes
            app.OriginalAxes = uiaxes(app.UIFigure);
            app.OriginalAxes.Position = [450 260 400 180];
            title(app.OriginalAxes, 'Original Signal')
            xlabel(app.OriginalAxes, 'Samples')
            ylabel(app.OriginalAxes, 'Amplitude')
            grid(app.OriginalAxes,'on')

            % Filtered Signal Axes
            app.FilteredAxes = uiaxes(app.UIFigure);
            app.FilteredAxes.Position = [450 60 400 180];
            title(app.FilteredAxes, 'Filtered Signal')
            xlabel(app.FilteredAxes, 'Samples')
            ylabel(app.FilteredAxes, 'Amplitude')
            grid(app.FilteredAxes,'on')

            % Status Text
            app.StatusText = uilabel(app.UIFigure);
            app.StatusText.Position = [20 20 860 22];
            app.StatusText.Text = 'Ready. Please load an audio file to begin.';
            app.StatusText.HorizontalAlignment = 'left';
            app.StatusText.FontWeight = 'bold';

            % Show the figure
            app.UIFigure.Visible = 'on';
        end
    end

    % App initialization and construction
    methods (Access = public)

        % Construct app
        function app = WinampEqualizer

            % Create and configure components
            createComponents(app)

            % Register the app with App Designer
            registerApp(app, app.UIFigure)

            if nargout == 0
                clear app
            end
        end

        % Code that executes before app deletion
        function delete(app)

            % Delete UIFigure when app is deleted
            delete(app.UIFigure)
        end
    end
end
