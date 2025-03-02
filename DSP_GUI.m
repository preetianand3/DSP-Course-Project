%% 
function DrowsinessDetectionGUI
    % Create the GUI figure
    hFig = figure('Name', 'Drowsiness Detection using EEG Signals', ...
                  'NumberTitle', 'off', ...
                  'Position', [100, 100, 800, 600], ...
                  'MenuBar', 'none', ...
                  'Resize', 'off');

    % Add UI components
    uicontrol('Style', 'text', 'String', 'Drowsiness Detection using EEG Signals', ...
              'FontSize', 14, 'FontWeight', 'bold', ...
              'Position', [200, 550, 400, 30]);

    uicontrol('Style', 'pushbutton', 'String', 'Load Data', ...
              'Position', [50, 500, 100, 30], ...
              'Callback', @loadData);

    uicontrol('Style', 'pushbutton', 'String', 'Process Data', ...
              'Position', [200, 500, 100, 30], ...
              'Callback', @processData);

    statusText = uicontrol('Style', 'text', 'String', 'Status: Waiting for input...', ...
                           'Position', [350, 500, 400, 30], ...
                           'HorizontalAlignment', 'left');

    resultText = uicontrol('Style', 'text', 'String', 'Drowsiness Detection Result: ', ...
                           'FontSize', 12, 'FontWeight', 'bold', ...
                           'Position', [50, 50, 700, 30], ...
                           'HorizontalAlignment', 'left');

    axes1 = axes('Parent', hFig, 'Position', [0.1, 0.3, 0.35, 0.4]);
    title('Power Spectrum');
    xlabel('Frequency Band');
    ylabel('Power (Magnitude Squared)');
    grid on;

    % Variables to store data
    eeg_signal = [];
    Fs = 250; % Sampling frequency

    % Callback functions
    function loadData(~, ~)
        [file, path] = uigetfile('*.xlsx', 'Select EEG Data File');
        if isequal(file, 0)
            set(statusText, 'String', 'Status: Data loading canceled.');
            return;
        end
        fullFileName = fullfile(path, file);
        [data, ~, ~] = xlsread(fullFileName);

        if isempty(data)
            set(statusText, 'String', 'Status: No numeric data found in the file.');
            return;
        end

        eeg_signal = data(:, 1); % Assuming EEG signal is in the first column
        set(statusText, 'String', 'Status: Data loaded successfully.');
    end

    function processData(~, ~)
        if isempty(eeg_signal)
            set(statusText, 'String', 'Status: No data loaded. Please load data first.');
            return;
        end

        % Process the EEG signal
        N = length(eeg_signal);

        % Perform FFT
        fft_signal = fft(eeg_signal);
        frequencies = (0:N-1) * (Fs / N);

        % Notch filter (50 Hz)
        notch_freq = 50;
        notch_bandwidth = 2;
        notch_start = round((notch_freq - notch_bandwidth / 2) * N / Fs);
        notch_end = round((notch_freq + notch_bandwidth / 2) * N / Fs);
        fft_signal(notch_start:notch_end) = 0;
        fft_signal(end-notch_end:end-notch_start) = 0;
        notch_filtered_signal = ifft(fft_signal, 'symmetric');

        % Bandpass filters for Theta (4-8 Hz) and Alpha (8-13 Hz)
        [b_theta, a_theta] = butter(4, [4 8] / (Fs / 2), 'bandpass');
        theta_band_signal = filtfilt(b_theta, a_theta, notch_filtered_signal);

        [b_alpha, a_alpha] = butter(4, [8 13] / (Fs / 2), 'bandpass');
        alpha_band_signal = filtfilt(b_alpha, a_alpha, notch_filtered_signal);

        % Power calculation
        fft_theta = fft(theta_band_signal);
        fft_alpha = fft(alpha_band_signal);

        theta_band_freq_range = (frequencies >= 4) & (frequencies <= 8);
        theta_power = sum(abs(fft_theta(theta_band_freq_range)).^2) / N;

        alpha_band_freq_range = (frequencies >= 8) & (frequencies <= 13);
        alpha_power = sum(abs(fft_alpha(alpha_band_freq_range)).^2) / N;

        % Debugging outputs
        fprintf('Theta Power: %.4f\n', theta_power);
        fprintf('Alpha Power: %.4f\n', alpha_power);

        % Drowsiness detection
        if theta_power > alpha_power
            drowsiness_result = 'Drowsiness detected';
            sound(sin(1:0.25:1000), 44100); % Play alert sound with valid sampling rate
        else
            drowsiness_result = 'No drowsiness detected';
        end

        % Update GUI
        set(resultText, 'String', ['Drowsiness Detection Result: ', drowsiness_result]);
        set(statusText, 'String', 'Status: Processing complete.');

        % Plot power spectrum
        bar(axes1, categorical({'Theta', 'Alpha'}), [theta_power, alpha_power]);
        title(axes1, 'Theta vs Alpha Power');
        xlabel(axes1, 'Frequency Band');
        ylabel(axes1, 'Power (Magnitude Squared)');
        grid(axes1, 'on');
    end
end