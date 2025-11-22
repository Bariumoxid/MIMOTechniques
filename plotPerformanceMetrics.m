% plotPerformanceMetrics.m
% Updated for structured .mat files with simResults.{simThroughput, maxThroughput, bler}

clear; clc; close all;

% === MANUALLY SPECIFY YOUR FILES HERE ===
resultsFolder = './results/';
fileNames = {
    'simResult_HARQ_perfectCSI_CDL-C_8Tx_4Rx_4Layer_10Hz.mat'
    'simResult_HARQ_imperfectCSI_CDL-C_8Tx_4Rx_4Layer_10Hz.mat'
    'simResult_1Y8Txsubarray_CDL-C_8Tx_4Rx_4Layer_10HzV2.mat'

    % Add more filenames here
};

legendNames = {
    'Option 3 Perfect CSI'
    'Option 3 Imperfect CSI'
    'Option 1Y Perfect CSI'


};

% Define the SNR vector (based on your simulation sweep)
snrVec = -5:1:25;

% Plot formatting
colors = lines(numel(fileNames));
markers = {'o', 's', 'd', '^', 'v', '>', '<', 'p', 'h', 'x'};

% Create figures
fig1 = figure; hold on; grid on;
xlabel('SNR (dB)'); ylabel('Throughput (%)');
title('Throughput vs. SNR');
set(gca, 'FontSize', 12);

% fig2 = figure; hold on; grid on;
% xlabel('SNR (dB)'); ylabel('BLER');
% title('BLER vs. SNR');
% set(gca, 'YScale', 'log', 'FontSize', 12);
lineStyles = {'-', '--', ':', '-.'};  % optional

for i = 1:length(fileNames)
    filePath = fullfile(resultsFolder, fileNames{i});
    data = load(filePath);
    % Extract and transpose as needed
    simThroughput = double(data.simResults.simThroughput);  % 1xN
    maxThroughput = double(data.simResults.maxThroughput);
    bler = double(data.simResults.bler);

    if i == 10
        throughputPercent = (simThroughput(:, 1) ./ maxThroughput(:, 1)) * 100;
        bler = bler(:, 1);
    elseif i == 9
        throughputPercent = (simThroughput(:, 2) ./ maxThroughput(:, 2)) * 100;
        bler = bler(:, 2);
    else
        % Compute throughput %
        throughputPercent = (simThroughput ./ maxThroughput) * 100;
        %throughputPercent = simThroughput;
    end

    % Legend name from file name (remove .mat)
    legendName = legendNames{i};
    markerStyle = markers{mod(i-1,numel(markers))+1};
    lineStyle = lineStyles{mod(i-1,numel(lineStyles))+1};  % optional
    xOffset = (i - (length(fileNames)+1)/2) * 0.1;  % Tiny offset to prevent overlap

    % Plot Throughput
    figure(fig1);
    plot(snrVec + xOffset, throughputPercent, ...
        'LineWidth', 1.8, ...
        'LineStyle', lineStyle, ...
        'Color', colors(i,:), ...
        'Marker', markerStyle, ...
        'MarkerSize', 4, ...
        'MarkerFaceColor', 'none', ...
        'DisplayName', legendName);

    % % Plot BLER
    % figure(fig2);
    % semilogy(snrVec + xOffset, bler, ...
    %     'LineWidth', 1.8, ...
    %     'LineStyle', lineStyle, ...
    %     'Color', colors(i,:), ...
    %     'Marker', markerStyle, ...
    %     'MarkerSize', 4, ...
    %     'MarkerFaceColor', 'none', ...
    %     'DisplayName', legendName);
end

% set([fig1, fig2], 'Color', 'w');  % white background
% set(findall([fig1, fig2], '-property', 'FontSize'), 'FontSize', 12);

set(fig1, 'Color', 'w');  % white background
set(findall(fig1, '-property', 'FontSize'), 'FontSize', 12);

% Final formatting
figure(fig1);
set(gcf, 'Position', [100, 100, 900, 600]);  % [left, bottom, width, height]
lgd1 = legend('Location', 'southeast');
set(lgd1, ...
    'Box', 'off', ...           % No border
    'Color', 'none', ...        % Transparent background
    'FontSize', 8);            % Optional font size
ylim([0 100]);
xlim([-7 27]);

% figure(fig2);
% set(gcf, 'Position', [1100, 100, 900, 600]);  % second figure next to first
% lgd2 = legend('Location', 'southwest');
% set(lgd2, ...
%     'Box', 'off', ...           % No border
%     'Color', 'none', ...        % Transparent background
%     'FontSize', 8);            % Optional font size
% ylim([1e-3 1]);
% xlim([-7 27]);

matlab2tikz('figures/throughput_subarrayv2.tex', 'figurehandle', fig1, ...
            'height', '\figureheight', ...
            'width', '\figurewidth', ...
            'showInfo', false, ...
            'extraAxisOptions', {
        'legend style={font=\scriptsize}'});

% matlab2tikz('figures/BLER_test.tex', 'figurehandle', fig2, ...
%             'height', '\figureheight', ...
%             'width', '\figurewidth', ...
%             'showInfo', false, ...
%             'extraAxisOptions', {
%         'legend style={font=\scriptsize}'});