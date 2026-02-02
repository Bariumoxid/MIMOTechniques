%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%Version 2
Version="2.0";
close all force
clearvars
clc

%Can either flex layer + modulation + TCR or flex modulation + TCR
%Save function added
%CDL

Save_to_File=true; %true, false will save plotted figures too as a reference
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
Frames = 2;
Range = -5:5:40;

RIRestriction = [1 1 1 1 0 0 0 0];

PO=[40 0];  % Peridocity and offset of the CSI report in slots % (4,5,8,10,16,20,32,40,64,80,160,320,640).
CQIMode = 'Wideband'; % 'Wideband','Subband'
PMIMode = 'Wideband'; % 'Wideband','Subband'
CodebookType = 'Type1SinglePanel'; % 'Type1SinglePanel','Type1MultiPanel','Type2', 'eType2'
    %"Type1MultiPanel", CSI-RS ports must be 8, 16, or 32: -> Only can be used
    %for 8 Tx case.
    %'Type2' max. rank is 2
SubbandSize = 8; % only required for 'subband', subband size in RB (4,8,16,32) 能被BWP size整除, generally 8, 16 for BWP 106 (NSizeGrid)
CodebookMode = 1; %1, 2 1: sparse, 2: dense, should only be valid to CB1?
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

simParameters = struct();       % Clear simParameters variable to contain all key simulation parameters 
simParameters.NFrames = Frames;      % Number of 10 ms frames
simParameters.SNRIn = Range; % SNR range (dB)

simParameters.PerfectChannelEstimator = false;
simParameters.DisplaySimulationInformation = false;
simParameters.DisplayDiagnostics = false;
% SCS carrier parameters
simParameters.Carrier = nrCarrierConfig;         % Carrier resource grid configuration
simParameters.Carrier.NSizeGrid = 106;            % Bandwidth in number of resource blocks
simParameters.Carrier.SubcarrierSpacing = 30;    % 15, 30, 60, 120 (kHz)
simParameters.Carrier.CyclicPrefix = 'Normal';   % 'Normal' or 'Extended' (Extended CP is relevant for 60 kHz SCS only)
simParameters.Carrier.NCellID = 1;               % Cell identity

simParameters.PDSCH = nrPDSCHConfig;      % This PDSCH definition is the basis for all PDSCH transmissions in the simulation

% Define PDSCH time allocation in a slot
simParameters.PDSCH.MappingType = "A"; % PDSCH mapping type ('A'(slot-wise),'B'(non slot-wise))
symAlloc = [2 simParameters.Carrier.SymbolsPerSlot-2];  % Starting symbol and number of symbols of each PDSCH allocation
simParameters.PDSCH.SymbolAllocation = symAlloc;

% Define PDSCH frequency resource allocation per slot to be full grid 
simParameters.PDSCH.PRBSet = 0:simParameters.Carrier.NSizeGrid-1;

% Scrambling identifiers
simParameters.PDSCH.NID = simParameters.Carrier.NCellID;
simParameters.PDSCH.RNTI = 1;

simParameters.PDSCH.DMRS.DMRSTypeAPosition       = 2; % Mapping type A only. First DM-RS symbol position (2,3)
simParameters.PDSCH.DMRS.DMRSLength              = 2; % Number of front-loaded DM-RS symbols (1(single symbol),2(double symbol))
simParameters.PDSCH.DMRS.DMRSAdditionalPosition  = 1; % Additional DM-RS symbol positions (max range 0...3)
simParameters.PDSCH.DMRS.DMRSConfigurationType   = 2; % DM-RS configuration type (1,2)
simParameters.PDSCH.DMRS.NumCDMGroupsWithoutData = 3; % CDM groups without data (1,2,3)

simParameters.PDSCHExtension = struct();
simParameters.PDSCHExtension.PRGBundleSize = 4; % 2, 4, or [] to signify "wideband"
simParameters.PDSCHExtension.MCSTable      = 'Table1'; % 'Table1',...,'Table4'
simParameters.PDSCHExtension.XOverhead     = [ ]; % 0, 6, 12, 18, or [] for automatic selection.

simParameters.PDSCHExtension.LDPCDecodingAlgorithm = "Normalized min-sum";
simParameters.PDSCHExtension.MaximumLDPCIterationCount = 6;

simParameters.TransmitAntennaArray.NumPanels        = 1; % Number of transmit panels in horizontal dimension (Ng)
simParameters.TransmitAntennaArray.PanelDimensions  = [2 1]; % Number of columns and rows in the transmit panel (N1, N2)
simParameters.TransmitAntennaArray.NumPolarizations = 2; % Number of transmit polarizations
simParameters.ReceiveAntennaArray.NumPanels         = 1; % Number of receive panels in horizontal dimension (Ng)
simParameters.ReceiveAntennaArray.PanelDimensions   = [2 1];                % Number of columns and rows in the receive panel (N1, N2)
simParameters.ReceiveAntennaArray.NumPolarizations  = 2; % Number of receive polarizations

simParameters.NTxAnts = numAntennaElements(simParameters.TransmitAntennaArray);
simParameters.NRxAnts = numAntennaElements(simParameters.ReceiveAntennaArray);

simParameters.CSIRS = nrCSIRSConfig;
simParameters.CSIRS.CSIRSType = 'nzp'; % 'nzp','zp'
simParameters.CSIRS.RowNumber = 4; % 1...18
simParameters.CSIRS.NumRB = simParameters.Carrier.NSizeGrid - simParameters.CSIRS.RBOffset;
simParameters.CSIRS.CSIRSPeriod = PO;
simParameters.CSIRS.SymbolLocations = 4;
simParameters.CSIRS.SubcarrierLocations = 0;
simParameters.CSIRS.Density = 'one';

disp(['Number of CSI-RS ports: ' num2str(simParameters.CSIRS.NumCSIRSPorts) '.'])

csirsCDMLengths = getCSIRSCDMLengths(simParameters.CSIRS);

% Check that the number of CSI-RS ports and transmit antenna elements match
% and the consistency of multiple CSI-RS resources
validateCSIRSConfig(simParameters.Carrier,simParameters.CSIRS,simParameters.NTxAnts);

simParameters.CSIReportMode = 'RI-PMI-CQI'; % 'RI-PMI-CQI','AI CSI compression','Perfect CSI'

simParameters.CSIReportConfig = struct();
simParameters.CSIReportConfig.Period = PO;  % Peridocity and offset of the CSI report in slots

if simParameters.CSIReportMode == "RI-PMI-CQI"  
    
    simParameters.CSIReportConfig.CQITable          = "Table1"; % 'Table1','Table2','Table3'
    simParameters.CSIReportConfig.CQIMode           = CQIMode; % 'Wideband','Subband'
    simParameters.CSIReportConfig.PMIMode           = CQIMode; % 'Wideband','Subband'
    simParameters.CSIReportConfig.CodebookType      = CodebookType; % 'Type1SinglePanel','Type1MultiPanel','Type2','eType2'
    simParameters.CSIReportConfig.SubbandSize       = SubbandSize; % Subband size in RB (4,8,16,32)
    simParameters.CSIReportConfig.CodebookMode      = CodebookMode; % 1,2
    simParameters.CSIReportConfig.RIRestriction     = RIRestriction;                   % Empty for no rank restriction
    simParameters.CSIReportConfig.NumberOfBeams     = 2; % 2,3,4. Only for Type II codebooks
    simParameters.CSIReportConfig.PhaseAlphabetSize = 8; % 4,8. Only for Type II codebooks  
    simParameters.CSIReportConfig.SubbandAmplitude  = true;                  % true/false. Only for Type II codebooks
    simParameters.CSIReportConfig.ParameterCombination = 1;             % 1...8. Only for Enhanced Type II codebooks
    simParameters.CSIReportConfig.NumberOfPMISubbandsPerCQISubband = 1; % 1,2. Only for Enhanced Type II codebooks
    simParameters.CSIReportConfig.NStartBWP         = [];                                  % Empty to signal the entire carrier
    simParameters.CSIReportConfig.NSizeBWP          = [];                                  % Empty to signal the entire carrier

    % Configure the CSI report with the antenna panel dimensions specified
    simParameters.CSIReportConfig.PanelDimensions = getCSIReportPanelDimensions(simParameters.TransmitAntennaArray,simParameters.CSIReportConfig.CodebookType);
    
    % Adjust the rank restriction based on the number of ports supported by
    % the DM-RS configuration, as defined in TS 38.211 Table 7.4.1.1.2-5.
    simParameters.CSIReportConfig.RIRestriction = updateRankRestriction(simParameters.PDSCH.DMRS,simParameters.CSIReportConfig);
else % AI CSI compression

    % Specify the file name of the AI neural network
    simParameters.AINetworkFilename = 'csiTrainedNetwork.mat'; 

end

simParameters.UEProcessingDelay = 7;
simParameters.BSProcessingDelay = 1;

simParameters.DelayProfile = 'CDL-C';   % 'CDL-A',...,'CDL-E','TDL-A',...,'TDL-E'
simParameters.DelaySpread = 300e-9;     % s
simParameters.MaximumDopplerShift = 10;  % Hz

simParameters.Channel = createChannel(simParameters);

% Array to store the maximum throughput for all SNR points
maxThroughput = zeros(length(simParameters.SNRIn),1); 
% Array to store the simulation throughput for all SNR points
simThroughput = zeros(length(simParameters.SNRIn),1);
log_snr  = cell(numel(simParameters.SNRIn),1);
log_slot = cell(numel(simParameters.SNRIn),1);
log_layer = cell(numel(simParameters.SNRIn),1);
log_mod   = cell(numel(simParameters.SNRIn),1);
log_tcr  = cell(numel(simParameters.SNRIn),1);

% Cell array to store CSI reports per SNR point
CSIReport = {};

parfor snrIdx = 1:numel(simParameters.SNRIn)
% parfor snrIdx = 1:numel(simParameters.SNRIn)
% To reduce the total simulation time, you can execute this loop in
% parallel by using the Parallel Computing Toolbox. Comment out the 'for'
% statement and uncomment the 'parfor' statement.
    lsnr   = [];
    lslot  = [];
    llayer = [];
    lmod   = {};
    ltcr   = [];
    % Reset the random number generator for repeatability
    rng(0,"twister");

    % Display simulation information at this SNR point
    displaySNRPointProgress(simParameters,snrIdx);

    % Take full copies of the simulation-level parameter structures so that
    % they are not PCT broadcast variables when using parfor
    simParamLocal = simParameters;

    % Extract CSI feedback configuration parameters
    csiFeedbackOpts = getCSIFeedbackOptions(simParamLocal,snrIdx);

    % Set up the transmitter, propagation channel, and receiver
    [carrier,encodeDLSCH,pdsch,pdschextra,csirs,wtx] = setupTransmitter(simParamLocal);
    [channel,maxChDelay] = setupChannel(simParamLocal);
    [decodeDLSCH,timingOffset,N0,noiseEst,csiReports,csiAvailableSlots] = setupReceiver(simParamLocal,channel,snrIdx,csiFeedbackOpts);

    % Total number of slots in the simulation period
    NSlots = simParamLocal.NFrames * carrier.SlotsPerFrame;

    % Loop over the entire waveform length
    for nslot = 0:NSlots-1

        % Update the carrier slot numbers for new slot
        carrier.NSlot = nslot;

        % Use new CSI report to configure the number of layers and
        % modulation of the PDSCH and target code rate of the DL-SCH if
        % there is a new report available.
        [isNewReport,repIdx] = ismember(nslot,csiAvailableSlots);
        if isNewReport
            [pdsch.Modulation,pdschextra.TargetCodeRate,wtx] = hCSIDecode(carrier,pdsch,pdschextra,csiReports(repIdx),csiFeedbackOpts);
            pdsch.NumLayers = size(wtx,1);
            encodeDLSCH.TargetCodeRate = pdschextra.TargetCodeRate;
        end
        lsnr(end+1)   = simParameters.SNRIn(snrIdx);
        lslot(end+1)  = nslot;
        lmod{end+1} = char(pdsch.Modulation);
        llayer(end+1) = double(pdsch.NumLayers);
        ltcr(end+1)   = pdschextra.TargetCodeRate;

        % Create an OFDM resource grid for a slot
        dlGrid = nrResourceGrid(carrier,csirs.NumCSIRSPorts);

        % CSI-RS mapping to the slot resource grid
        [csirsInd,csirsInfo] = nrCSIRSIndices(carrier,csirs);
        csirsSym = nrCSIRS(carrier,csirs);
        dlGrid(csirsInd) = csirsSym;
        csirsTransmission = ~isempty(csirsInd);

        % PDSCH reserved REs for CSI-RS
        pdsch.ReservedRE = csirsInd-1; % 0-based indices
        
        % PDSCH generation
        % Calculate the transport block sizes for the transmission in the slot
        [pdschIndices,pdschIndicesInfo] = nrPDSCHIndices(carrier,pdsch);
        trBlkSizes = nrTBS(pdsch.Modulation,pdsch.NumLayers,numel(pdsch.PRBSet),pdschIndicesInfo.NREPerPRB,pdschextra.TargetCodeRate,pdschextra.XOverhead);

        % Transport block generation
        for cwIdx = 1:pdsch.NumCodewords
            % New data for current codeword then create a new DL-SCH transport block
            trBlk = randi([0 1],trBlkSizes(cwIdx),1);
            setTransportBlock(encodeDLSCH,trBlk,cwIdx-1);
            resetSoftBuffer(decodeDLSCH,cwIdx-1);
        end

        % Encode the DL-SCH transport blocks
        RV = zeros(1,pdsch.NumCodewords);
        codedTrBlocks = encodeDLSCH(pdsch.Modulation,pdsch.NumLayers, ...
            pdschIndicesInfo.G,RV);

        % PDSCH modulation and precoding
        pdschSymbols = nrPDSCH(carrier,pdsch,codedTrBlocks);
        [pdschAntSymbols,pdschAntIndices] = nrPDSCHPrecode(carrier,pdschSymbols,pdschIndices,wtx);
        dlGrid(pdschAntIndices) = pdschAntSymbols;        

        % PDSCH DM-RS precoding and mapping
        dmrsSymbols = nrPDSCHDMRS(carrier,pdsch);
        dmrsIndices = nrPDSCHDMRSIndices(carrier,pdsch);
        [dmrsAntSymbols,dmrsAntIndices] = nrPDSCHPrecode(carrier,dmrsSymbols,dmrsIndices,wtx);
        dlGrid(dmrsAntIndices) = dmrsAntSymbols;

        % Warn if CSI-RS and PDSCH DM-RS resources overlap
        if any(ismember(dmrsIndices,csirsInd))
            warning("CSI-RS and PDSCH DM-RS resources overlap in the resource grid. This can result in decoding failures.")
        end

        % OFDM modulation
        txWaveform = nrOFDMModulate(carrier,dlGrid);

        % Pass data through channel model. Append zeros at the end of the
        % transmitted waveform to flush channel content. These zeros take
        % into account any delay introduced in the channel.
        txWaveform = [txWaveform; zeros(maxChDelay,size(txWaveform,2))]; %#ok<AGROW>
        [rxWaveform,ofdmResponse,tOffset] = channel(txWaveform,carrier);
        
        % Add AWGN to the received time-domain waveform
        noise = N0*randn(size(rxWaveform),"like",1i);
        rxWaveform = rxWaveform + noise;

        if simParamLocal.PerfectChannelEstimator
            % For perfect synchronization, use the timing offset obtained
            % from the channel
            timingOffset = tOffset;
        else
            % Practical synchronization. Correlate the received waveform
            % with the PDSCH DM-RS to obtain the timing offset and
            % correlation magnitude. The receiver updates the timing offset
            % only when the correlation magnitude is high.
            [t,mag] = nrTimingEstimate(carrier,rxWaveform,dmrsIndices,dmrsSymbols); 
            timingOffset = hSkipWeakTimingOffset(timingOffset,t,mag);
            % Display a warning if the estimated timing offset exceeds the
            % maximum channel delay
            if timingOffset > maxChDelay
                warning(['Estimated timing offset (%d) is greater than the maximum channel delay (%d).' ...
                    ' This will result in a decoding failure. This may be caused by low SNR,' ...
                    ' or not enough DM-RS symbols to synchronize successfully.'],timingOffset,maxChDelay);
            end
        end
        rxWaveform = rxWaveform(1+timingOffset:end,:);

        % Perform OFDM demodulation on the received data to recreate the
        % resource grid, including padding in the event that practical
        % synchronization results in an incomplete slot being demodulated
        rxGrid = nrOFDMDemodulate(carrier,rxWaveform);
        [K,L,R] = size(rxGrid);
        if (L < carrier.SymbolsPerSlot)
            rxGrid = cat(2,rxGrid,zeros(K,carrier.SymbolsPerSlot-L,R));
        end

        if simParamLocal.PerfectChannelEstimator
            % For perfect channel estimate, use the OFDM channel response
            % obtained from the channel
            Hest = ofdmResponse;

            % Get PDSCH resource elements from the received grid and 
            % channel estimate
            [pdschRx,pdschHest,~,pdschHestIndices] = nrExtractResources(pdschIndices,rxGrid,Hest);

            % Apply precoding to channel estimate
            pdschHest = nrPDSCHPrecode(carrier,pdschHest,pdschHestIndices,permute(wtx,[2 1 3]));
        else
            % Practical channel estimation between the received grid and
            % each transmission layer, using the PDSCH DM-RS for each
            % layer. This channel estimate includes the effect of
            % transmitter precoding
            [Hest,noiseEst] = nrChannelEstimate(carrier,rxGrid,dmrsIndices,dmrsSymbols,PRGBundleSize = pdschextra.PRGBundleSize,CDMLengths = pdsch.DMRS.CDMLengths);

            % Average noise estimate across PRGs and layers
            noiseEst = mean(noiseEst,'all');
            
            % Get PDSCH resource elements from the received grid and
            % channel estimate
            [pdschRx,pdschHest] = nrExtractResources(pdschIndices,rxGrid,Hest);
        end

        % Equalization
        [pdschEq,eqCSIScaling] = nrEqualizeMMSE(pdschRx,pdschHest,noiseEst);

        % Decode PDSCH physical channel
        [dlschLLRs,rxSymbols] = nrPDSCHDecode(carrier,pdsch,pdschEq,noiseEst);
        
        % Display EVM per layer, per slot and per RB
        if (simParamLocal.DisplayDiagnostics)
            plotLayerEVM(NSlots,nslot,pdsch,size(dlGrid),pdschIndices,pdschSymbols,pdschEq);
        end
        
        % Scale LLRs
        eqCSIScaling = nrLayerDemap(eqCSIScaling); % CSI scaling layer demapping
        for cwIdx = 1:pdsch.NumCodewords
            Qm = length(dlschLLRs{cwIdx})/length(rxSymbols{cwIdx});        % bits per symbol
            eqCSIScaling{cwIdx} = repmat(eqCSIScaling{cwIdx}.',Qm,1);      % expand by each bit per symbol
            dlschLLRs{cwIdx} = dlschLLRs{cwIdx} .* eqCSIScaling{cwIdx}(:); % scale LLRs
        end
        
        % Decode the DL-SCH transport channel
        decodeDLSCH.TransportBlockLength = trBlkSizes;
        decodeDLSCH.TargetCodeRate = pdschextra.TargetCodeRate;
        [decbits,blkerr] = decodeDLSCH(dlschLLRs,pdsch.Modulation,pdsch.NumLayers,RV);

        % Store values to calculate throughput
        simThroughput(snrIdx) = simThroughput(snrIdx) + sum(~blkerr .* trBlkSizes);
        maxThroughput(snrIdx) = maxThroughput(snrIdx) + sum(trBlkSizes);

        log_snr{snrIdx}   = lsnr;
        log_slot{snrIdx}  = lslot;
        log_layer{snrIdx} = llayer;
        log_mod{snrIdx}   = lmod;
        log_tcr{snrIdx}   = ltcr;
        %fprintf("  trBlkSizes: [%d %d]\n", trBlkSizes(1), trBlkSizes(2));
        %fprintf("  blkerr:     [%d %d]\n", blkerr(1), blkerr(2));
        %fprintf("  Mod:        {'%s','%s'}\n", pdsch.Modulation{1}, pdsch.Modulation{2});
        %fprintf("  TCR:        [%.3f %.3f]\n", pdschextra.TargetCodeRate(1), pdschextra.TargetCodeRate(2));
        % CSI measurements and encoding 
        if csirsTransmission
            
            if ~simParamLocal.PerfectChannelEstimator
                % Consider only the NZP-CSI-RS symbols and indices for CSI-RS based
                % channel estimation
                nzpind = (csirsSym ~= 0);
                
                % Calculate practical channel estimate based on CSI-RS. Use
                % a time-averaging window that covers all of the
                % transmitted CSI-RS symbols.
                [Hest,noiseEst] = nrChannelEstimate(carrier,rxGrid, ...
                    csirsInd(nzpind),csirsSym(nzpind),'CDMLengths',csirsCDMLengths);
            end

            % Generate CSI report. Store the report for use at the
            % transmitter. The CSI feedback is subject to a delay that
            % depends on the CSI report periodicity and the UE processing
            % delay. The slot in which the CSI is available to use at the
            % transmitter depends on the BS processing delay as well.
            rxCSIReport = hCSIEncode(carrier,csirs,Hest,noiseEst,csiFeedbackOpts);
            csiFeedbackSlot = nextCSISlot(csiFeedbackOpts.CSIReportPeriod,1+nslot+simParamLocal.UEProcessingDelay);
            csiAvailableSlots(end+1) = 1+csiFeedbackSlot+simParamLocal.BSProcessingDelay; %#ok<SAGROW>
            csiReports(end+1) = rxCSIReport; %#ok<SAGROW>
        end

        % Print slot-wise information
        if simParamLocal.DisplaySimulationInformation
            printSlotInfo(NSlots,carrier,pdsch,pdschextra,blkerr,trBlkSizes./pdschIndicesInfo.G,csirsTransmission,csiReports,repIdx)
        end
    end

    % Store CSI report for each SNR point
    CSIReport{snrIdx} = csiReports; %#ok<SAGROW>
    
    % Display the results dynamically in the command window
    if simParamLocal.DisplaySimulationInformation
        fprintf('\n');
    end
    fprintf('\nThroughput(Mbps) for %d frame(s) = %.4f\n',simParamLocal.NFrames,1e-6*simThroughput(snrIdx)/(simParamLocal.NFrames*10e-3));

end

log_tcr_f=vertcat(log_tcr{:});
log_layer_f=vertcat(log_layer{:});
log_slot_f=vertcat(log_slot{:});
log_mod_f=vertcat(log_mod{:});

log_tcr_mean = mean(log_tcr_f, 2);
log_layer_mean = mean(log_layer_f, 2);

if Save_to_File
    timestamp = datestr(datetime('now'), 'yyyy-mm-dd_HHMM');
    filename = sprintf( ...
    '%s_%s_L%s_%dHz', ...
    timestamp, ...
    simParameters.DelayProfile, ...
    rankrestrictionfromRI(RIRestriction), ...
    simParameters.MaximumDopplerShift);
    resultsFolder = './results_updated/';
    fullResultsPath = fullfile(resultsFolder, filename);

    if ~exist(fullResultsPath, 'dir')
        mkdir(fullResultsPath);
    end
end
    

snrVals = simParameters.SNRIn;
nSNR = numel(snrVals);

mods = {'QPSK','16QAM','64QAM','256QAM'};
nMod = numel(mods);

modFrac = zeros(nSNR, nMod);  % 每行一个 SNR

for i = 1:nSNR
    m = log_mod{i};      % cell array of char
    N = numel(m);
    for k = 1:nMod
        modFrac(i,k) = sum(strcmp(m, mods{k})) / N;
    end
end

tcrFrac = zeros(nSNR,3); % low / mid / high

for i = 1:nSNR
    tcr = log_tcr{i};
    N = numel(tcr);

    tcrFrac(i,1) = sum(tcr < 0.4) / N;
    tcrFrac(i,2) = sum(tcr >= 0.4 & tcr < 0.6) / N;
    tcrFrac(i,3) = sum(tcr >= 0.6) / N;
end

figure('Name','Throughput % vs SNR', 'NumberTitle','off');
plot(simParameters.SNRIn, 100* simThroughput./maxThroughput, '-s', 'LineWidth', 1.5);
xlabel('SNR (dB)');
ylabel('Throughput (%)');
grid on;
title(sprintf('%s (%dx%d) / NRB=%d / SCS=%dkHz / CSI: %s', ...
              simParameters.DelayProfile,simParameters.NTxAnts,simParameters.NRxAnts, ...
              simParameters.Carrier.NSizeGrid,simParameters.Carrier.SubcarrierSpacing,...
              char(simParameters.CSIReportMode)));
saveas(gcf, fullfile(fullResultsPath,  'Throughput% vs SNR.png'));


figure('Name','Throughput Mbps vs SNR', 'NumberTitle','off');
plot(simParameters.SNRIn,1e-6*simThroughput/(simParameters.NFrames*10e-3),'o-.')
xlabel('SNR (dB)'); ylabel('Throughput (Mbps)'); grid on;
title(sprintf('%s (%dx%d) / NRB=%d / SCS=%dkHz / CSI: %s', ...
              simParameters.DelayProfile,simParameters.NTxAnts,simParameters.NRxAnts, ...
              simParameters.Carrier.NSizeGrid,simParameters.Carrier.SubcarrierSpacing,...
              char(simParameters.CSIReportMode)));
saveas(gcf, fullfile(fullResultsPath, 'Mbps vs SNR.png'));

figure('Name','Modulation selection vs SNR', 'NumberTitle','off');
bar(snrVals, modFrac, 'stacked');
xlabel('SNR (dB)');
ylabel('Probability');
legend(mods, 'Location','northwest');
title('Modulation distribution per SNR');
saveas(gcf, fullfile(fullResultsPath, 'Modulation_Selection_vs_SNR.png')); % Save as image

figure('Name','Target code rate distribution vs SNR', 'NumberTitle','off');
subplot(1,2,1)
bar(snrVals, tcrFrac, 'stacked');
xlabel('SNR (dB)');
ylabel('Probability');
legend({'Low TCR','Mid TCR','High TCR'}, 'Location','northwest');
title('Target code rate distribution per SNR');

subplot(1,2,2);  % 当前是第二个子图
plot(snrVals, log_tcr_mean, '-o', 'LineWidth', 2);
xlabel('SNR (dB)');
ylabel('Average TCR');
title('Average TCR per SNR');
grid on;

saveas(gcf, fullfile(fullResultsPath,'Target_Code_Rate_vs_SNR.png')); % Save as image

figure('Name','Layer selection behaviour vs SNR', ...
       'NumberTitle','off');
hold on;


snrVals = simParameters.SNRIn;
nSNR = numel(snrVals);

meanLayer = zeros(nSNR,1);

baseColor = [0.1 0.3 0.6];   % 单一颜色（深蓝，论文友好）

for i = 1:nSNR
    L = log_layer{i};

    % mean layer
    meanLayer(i) = mean(L);

    % unique layers at this SNR
    layers = unique(L);

    for k = 1:numel(layers)
        lv = layers(k);
        p  = mean(L == lv);   % probability

        % bubble size (area scaling)
        bubbleSize = 900 * p + 20;  % 可微调 900 / 20

        scatter(snrVals(i), lv, bubbleSize, ...
            'MarkerFaceColor', baseColor, ...
            'MarkerEdgeColor', 'none', ...
            'MarkerFaceAlpha', 0.5);
    end
end

% mean curve
plot(snrVals, meanLayer, '-k', ...
    'LineWidth', 2);

xlabel('SNR (dB)');
ylabel('Number of layers');
title('Layer selection behaviour (bubble size = probability)');
grid on;
% 强制 y 轴整数
yticks(1:max(cellfun(@max,log_layer)));

legend({'Layer selection probability','Mean number of layers'}, ...
       'Location','northwest');
saveas(gcf, fullfile(fullResultsPath, 'Layer_Selection_vs_SNR.png'));


%%%
%if simParameters.CSIReportMode == "RI-PMI-CQI"
 %   perc = 90;
  %  plotCQI(simParameters,CSIReport,perc)    
%end




% Bundle key parameters and results into a combined structure for recording
simResults.simParameters = simParameters;
simResults.simThroughput = simThroughput;
simResults.maxThroughput = maxThroughput;
simResults.Throughput= 100* simThroughput./maxThroughput;
simResults.CSIReport = CSIReport;
simResults.log_tcr_mean=log_tcr_mean;
simResults.log_layer_mean=log_layer_mean;
simResults.Mbps=1e-6*simThroughput/(simParameters.NFrames*10e-3);

%flattended version
simResults.log_tcr_f=log_tcr_f;
simResults.log_layer_f=log_layer_f;
simResults.log_slot_f=vertcat(log_slot{:});
simResults.log_mod_f=vertcat(log_mod{:});

if Save_to_File
    save(fullfile(fullResultsPath, [filename, '.mat']), 'simResults', '-v7.3');
    disp("File Saved successfully")
end   
    
disp("End of the simulation");
%exit

function [carrier,eDLSCH,pdsch,pdschextra,csirs,wtx] = setupTransmitter(simParameters)
% Extract channel and signal-level parameters, create DL-SCH encoder, and
% initialize MIMO precoding matrix.

    carrier = simParameters.Carrier;
    pdsch = simParameters.PDSCH;
    pdschextra = simParameters.PDSCHExtension;
    csirs = simParameters.CSIRS;

    % Select XOverhead for TBS calculation if required
    if isempty(pdschextra.XOverhead)
        pdschextra.XOverhead = getXOverhead(carrier,csirs);
    end
    
    % Create DL-SCH encoder system object to perform transport channel
    % encoding
    eDLSCH = nrDLSCH;

    % Initialize MIMO precoding matrix
    wtx = 1;
    
end

function [decodeDLSCH,timingOffset,N0,noiseEst,csiReports,csiAvailableSlots] = setupReceiver(simParameters,channel,snrIdx,csiFeedbackOpts)
% Create and configure DL-SCH decoder. Obtain noise related quantities and
% initial CSI feedback from perfect channel knowledge.

    % Create DL-SCH decoder system object to perform transport channel
    % decoding
    decodeDLSCH = nrDLSCHDecoder;
    decodeDLSCH.LDPCDecodingAlgorithm = simParameters.PDSCHExtension.LDPCDecodingAlgorithm;
    decodeDLSCH.MaximumLDPCIterationCount = simParameters.PDSCHExtension.MaximumLDPCIterationCount;

    % Calculate noise standard deviation. Normalize noise power by the IFFT
    % size used in OFDM modulation, as the OFDM modulator applies this
    % normalization to the transmitted waveform.
    carrier = simParameters.Carrier;
    waveInfo = nrOFDMInfo(carrier);
    SNRdB = simParameters.SNRIn(snrIdx);
    SNR = 10^(SNRdB/10);    
    N0 = 1/sqrt(double(waveInfo.Nfft)*SNR);

    % Also normalize by the number of receive antennas if the channel
    % applies this normalization to the output
    chInfo = info(channel);
    if channel.NormalizeChannelOutputs
        N0 = N0/sqrt(chInfo.NumOutputSignals);
    end

    % Initial channel estimate
    [Hest,timingOffset] = getInitialChannelEstimate(carrier,channel,chInfo.MaximumChannelDelay);

    % Initial noise variance
    noiseEst = N0^2*double(waveInfo.Nfft);

    % Obtain an initial CSI report based on perfect channel estimates that
    % the Tx can use to adapt the transmission parameters.
    csirs = simParameters.CSIRS;

    % Initial CSI report using initial channel estimate
    csiFeedbackOpts.PerfectChannelEstimator = true;
    csirs.CSIRSPeriod = 'on';
    csiReports = hCSIEncode(carrier,csirs,Hest,noiseEst,csiFeedbackOpts);
    csiAvailableSlots = 0;

end

function channel = createChannel(simParameters)
% Create and configure the propagation channel. If the number of antennas
% is 1, configure only 1 polarization, otherwise configure 2 polarizations.

    % Number of antenna elements and polarizations
    nTxAnts = simParameters.NTxAnts;
    numTxPol = 1 + (nTxAnts>1);
    nRxAnts = simParameters.NRxAnts;
    numRxPol = 1 + (nRxAnts>1);
    
    if contains(simParameters.DelayProfile,'CDL')

        % Create CDL channel
        channel = nrCDLChannel;

        % Tx antenna array configuration in CDL channel. The number of antenna
        % elements depends on the panel dimensions. The size of the antenna
        % array is [M,N,P,Mg,Ng]. M and N are the number of rows and columns in
        % the antenna array. P is the number of polarizations (1 or 2). Mg and
        % Ng are the number of row and column array panels respectively. Note
        % that N1 and N2 in the panel dimensions follow a different convention
        % and denote the number of columns and rows, respectively.
        txArray = simParameters.TransmitAntennaArray;
        M = txArray.PanelDimensions(2);
        N = txArray.PanelDimensions(1);
        Ng = txArray.NumPanels;

        channel.TransmitAntennaArray.Size = [M N numTxPol 1 Ng];
        channel.TransmitAntennaArray.ElementSpacing = [0.5 0.5 1 1]; % Element spacing in wavelengths
        channel.TransmitAntennaArray.PolarizationAngles = [-45 45];  % Polarization angles in degrees
        
        % Rx antenna array configuration in CDL channel
        rxArray = simParameters.ReceiveAntennaArray;
        M = rxArray.PanelDimensions(2);
        N = rxArray.PanelDimensions(1);
        Ng = rxArray.NumPanels;

        channel.ReceiveAntennaArray.Size = [M N numRxPol 1 Ng];
        channel.ReceiveAntennaArray.ElementSpacing = [0.5 0.5 1 1];  % Element spacing in wavelengths
        channel.ReceiveAntennaArray.PolarizationAngles = [0 90];     % Polarization angles in degrees

    elseif contains(simParameters.DelayProfile,'TDL')

        channel = nrTDLChannel;
        channel.NumTransmitAntennas = nTxAnts;
        channel.NumReceiveAntennas = nRxAnts;

    else

        error('Channel not supported.')

    end

    % Configure common channel parameters: delay profile, delay spread, and
    % maximum Doppler shift
    channel.DelayProfile = simParameters.DelayProfile;
    channel.DelaySpread = simParameters.DelaySpread;
    channel.MaximumDopplerShift = simParameters.MaximumDopplerShift;

    % Configure the channel to return the OFDM response
    channel.ChannelResponseOutput = 'ofdm-response';

    % Get information about the baseband waveform after OFDM modulation step
    waveInfo = nrOFDMInfo(simParameters.Carrier);

    % Update channel sample rate based on carrier information
    channel.SampleRate = waveInfo.SampleRate;
    
end

function [channel,maxChannelDelay] = setupChannel(simParameters)
% Reset propagation channel and obtain the maximum channel delay

    % Extract carrier and channel
    channel = simParameters.Channel;
    channel.reset();

    % Get the channel information
    chInfo = info(channel);
    maxChannelDelay = chInfo.MaximumChannelDelay;

end

function [ofdmResponse,toffset] = getInitialChannelEstimate(carrier,channel,maxChannelDelay)
% Obtain OFDM channel response and timing offset before first transmission.
% This can be used to obtain initial transmission parameters.

    % Clone channel and configure channel to get OFDM channel response for
    % one slot
    channel = clone(channel);
    release(channel);
    channel.ChannelFiltering = false;
    ofdmInfo = nrOFDMInfo(carrier);
    channel.NumTimeSamples = (ofdmInfo.SampleRate*1e-3/carrier.SlotsPerSubframe) + maxChannelDelay;
    [ofdmResponse,toffset] = channel(carrier);
    
end

function XOverhead = getXOverhead(carrier,csirs)
% Calculate XOverhead for transport block size determination based on
% CSI-RS resource grid occupancy

    [~,csirsInfo] = nrCSIRSIndices(carrier,csirs);
    csirsRE = length(csirsInfo.KBarLBar{1})*length(csirsInfo.KPrime{1})*length(csirsInfo.LPrime{1});
    [~,XOverhead] = quantiz(csirsRE,[0 6 12],[0 6 12 18]);
    
    if csirsRE > XOverhead
        warning("The CSI-RS RE overhead is higher than the maximum 18. This can result in decoding failures.")
    end

end

function cdmLengths = getCSIRSCDMLengths(csirs)
%   CDMLENGTHS = getCSIRSCDMLengths(CSIRS) returns the CDM lengths given
%   the CSI-RS configuration object CSIRS.

    CDMType = csirs.CDMType;
    if ~iscell(csirs.CDMType)
        CDMType = {csirs.CDMType};
    end
    CDMTypeOpts = {'noCDM','fd-CDM2','CDM4','CDM8'};
    CDMLengthOpts = {[1 1],[2 1],[2 2],[2 4]};
    cdmLengths = CDMLengthOpts{strcmpi(CDMTypeOpts,CDMType{1})};

end

function csiFeedbackOpts = getCSIFeedbackOptions(simParameters,snrIdx)
% Create a CSI feedback algorithmic options structure

    csiFeedbackOpts = struct();
    csiFeedbackOpts.CSIReportMode = simParameters.CSIReportMode;
    csiFeedbackOpts.CSIReportPeriod = simParameters.CSIReportConfig.Period;
    csiFeedbackOpts.CSIReportConfig = simParameters.CSIReportConfig;
    csiFeedbackOpts.PerfectChannelEstimator = simParameters.PerfectChannelEstimator;
    csiFeedbackOpts.DMRSConfig = simParameters.PDSCH.DMRS;
    
    if simParameters.CSIReportMode == "AI CSI compression"
        % Copy additional link adaptation configuration for AI CSI compression mode
        csiFeedbackOpts.AINetworkFilename = simParameters.AINetworkFilename;
    
        % Download and extract a pretrained CSI network for AI CSI compression mode
        displayProgress = (snrIdx==1);
        helperCSINetDownloadData(displayProgress);
    end

end

function panelDimensions = getCSIReportPanelDimensions(antennaArray,codebookType)
% Configure the antenna array dimensions according to TS 38.214 Section
% 5.2.2.2 as a vector [N1,N2] for single-panel arrays and a vector
% [Ng,N1,N2] for multi-panel arrays.

    panelDimensions = antennaArray.PanelDimensions;
    
    % Add number of panels if codebook type is multi-panel
    if strcmpi(codebookType,'Type1MultiPanel')
        panelDimensions = [antennaArray.NumPanels panelDimensions];
    end
end

function csislot = nextCSISlot(period,nslot)
% Return the slot number of the first slot where CSI feedback can be
% reported according to the CSI report periodicity

    p = period(1); % Slot periodicity
    o = period(2); % Slot offset

    csislot = p*ceil((nslot-o)/p)+o;

end

function numElemenets = numAntennaElements(antArray)
% Calculate number of antenna elements in an antenna array

    numElemenets = antArray.NumPolarizations*antArray.NumPanels*prod(antArray.PanelDimensions);
    
end

function ranks = updateRankRestriction(dmrsConfig,CSIReportConfig)
% Restrict ranks unsupported by the DM-RS configuration
    ranks = CSIReportConfig.RIRestriction;
    
    if ~dmrsConfig.DMRSEnhancedR18 && (dmrsConfig.DMRSLength == 1) && strcmpi(CSIReportConfig.CodebookType, 'Type1SinglePanel')
        if (dmrsConfig.DMRSConfigurationType == 1)
            % Up to rank 4 for DM-RS configuration type 1
            dmrsRankRestriction = [ones(1,4) zeros(1,4)];
        else
            % Up to rank 6 for DM-RS configuration type 2
            dmrsRankRestriction = [ones(1,6) zeros(1,2)];
        end

        if isempty(ranks)
            ranks = ones(1,8);
        end

        ranks = ranks.*dmrsRankRestriction;

        fprintf('The PDSCH DM-RS configuration limits the maximum number of layers to %d. \n',find(dmrsRankRestriction,1,'last'));
    end
end

function validateCSIRSConfig(carrier,csirs,nTxAnts)
% validateCSIRSConfig(CARRIER,CSIRS,NTXANTS) validates the CSI-RS
% configuration, given the carrier specific configuration object CARRIER,
% CSI-RS configuration object CSIRS, and the number of transmit antennas
% NTXANTS.

    % Validate the number of CSI-RS ports
    if ~isscalar(unique(csirs.NumCSIRSPorts))
        error('nr5g:InvalidCSIRSPorts',...
            'All the CSI-RS resources must be configured to have the same number of CSI-RS ports.');
    end

    % Validate the CSI-RS and TX antenna array configuration
    if any(csirs.Ports_Options(csirs.RowNumber) ~= nTxAnts)
        rn = num2str(find(csirs.Ports_Options == nTxAnts),'%3d,');
        str = 'The number of CSI-RS ports must be equal to the number of Tx antenna elements. ';
        str = [str sprintf('For the Tx antenna array size configured, valid CSI-RS row numbers are (%s).',rn(1:end-1))];
        error(str)
    end

    % Validate the CDM lengths
    if ~iscell(csirs.CDMType)
        cdmType = {csirs.CDMType};
    else
        cdmType = csirs.CDMType;
    end
    if (~all(strcmpi(cdmType,cdmType{1})))
        error('nr5g:InvalidCSIRSCDMTypes',...
            'All the CSI-RS resources must be configured to have the same CDM lengths.');
    end
    if nTxAnts ~= csirs.NumCSIRSPorts(1)
        error('nr5g:InvalidNumTxAnts',['Number of transmit antennas (' num2str(nTxAnts)...
            ') must be equal to the number of CSI-RS ports (' num2str(csirs.NumCSIRSPorts(1)) ').']);
    end

    % Check for the overlap between the CSI-RS indices
    csirsInd = nrCSIRSIndices(carrier,csirs,"OutputResourceFormat",'cell');
    numRes = numel(csirsInd);
    csirsIndAll = cell(1,numRes);
    ratioVal = csirs.NumCSIRSPorts(1)/prod(getCSIRSCDMLengths(csirs));
    for resIdx = 1:numRes
        if ~isempty(csirsInd{resIdx})
            grid = nrResourceGrid(carrier,csirs.NumCSIRSPorts(1));
            [~,tempInd] = nrExtractResources(csirsInd{resIdx},grid);
            if numel(tempInd)/numel(csirsInd{resIdx}) ~= ratioVal
                error('nr5g:OverlappedCSIRSREsSingleResource',['CSI-RS indices of resource '...
                    num2str(resIdx) ' must be unique. Try changing the symbol or subcarrier locations.']);
            end
            csirsIndAll{resIdx} = tempInd(:);
            for idx = 1:resIdx-1
                overlappedInd = ismember(csirsIndAll{idx},csirsIndAll{resIdx});
                if any(overlappedInd)
                    error('nr5g:OverlappedCSIRSREsMultipleResources',['The resource elements of the '...
                        'configured CSI-RS resources must not overlap. Try changing the symbol or '...
                        'subcarrier locations of CSI-RS resource ' num2str(idx) ' and resource ' num2str(resIdx) '.']);
                end
            end
        end
    end
end

function displaySNRPointProgress(simParameters,snrIdx)
% Print SNR point progress

    str = ['\nSimulating transmission scheme 1 (%dx%d) and '...  
          'SCS=%dkHz with %s channel at %gdB SNR for %d 10ms frame(s)\n' ...
          'Using %s as CSI feedback.\n'];

    switch simParameters.CSIReportMode
        case 'RI-PMI-CQI'
            modeText = 'RI, PMI, and CQI';
        case 'AI CSI compression'
            modeText = 'compressed channel estimates';
        otherwise 
            modeText = 'channel estimates';
    end

    SNRdB = simParameters.SNRIn(snrIdx);
    fprintf(str,simParameters.NTxAnts,simParameters.NRxAnts,simParameters.Carrier.SubcarrierSpacing, ...
        simParameters.DelayProfile,SNRdB,simParameters.NFrames,modeText);

end

function printSlotInfo(NSlots,carrier,pdsch,pdschextra,blkerr,ECR,csirsTransmission,csiReports,reportIndex)
% Print information about the current slot transmission

    ncw = pdsch.NumCodewords;
    cwLayers = floor((pdsch.NumLayers + (0:ncw-1)) / ncw);
    infoStr = [];
    for cwIdx = 1:ncw
        if blkerr(cwIdx)
            infoStrCW = "Transmission failed";
        else
            infoStrCW = "Transmission succeeded";
        end
        infoStrCW = sprintf("%22s (Layers=%d, Mod=%5s, TCR=%.3f, CR=%.3f).",infoStrCW,cwLayers(cwIdx),pdsch.Modulation{cwIdx},pdschextra.TargetCodeRate(cwIdx),ECR(cwIdx));
        if (ncw>1)
            infoStr = sprintf('%s\n%s%s',infoStr,sprintf('CW%d: %s',cwIdx-1),infoStrCW);
        else
            infoStr = infoStrCW;
        end
    end
    
    csirsInfoStr = [];
    if csirsTransmission
        csirsInfoStr = "CSI-RS transmission. ";
    end

    csifbInfoStr = [];
    if carrier.NSlot == 0
        csifbInfoStr = 'Using initial CSI.';
    elseif reportIndex > 0
        csifbInfoStr = sprintf("Using CSI from NSlot=%2d.",csiReports(reportIndex).NSlot);
    end

    nslot = carrier.NSlot;
    fprintf('\n(%5.2f%%) NSlot=%2d: %s',100*(nslot+1)/NSlots,nslot,join([infoStr,csifbInfoStr,csirsInfoStr]));

end


function plotLayerEVM(NSlots,nslot,pdsch,siz,pdschIndices,pdschSymbols,pdschEqSymbols)
% Plot EVM information

    persistent slotEVM;
    persistent rbEVM
    persistent evmPerSlot;
    persistent numLayers;
    
    maxNumLayers = 8;
    if (nslot==0)
        slotEVM = comm.EVM;
        rbEVM = comm.EVM;
        evmPerSlot = NaN(NSlots,maxNumLayers);
        numLayers = pdsch.NumLayers;
        figure;
    else
        % Keep the maximum number of layers in the legend
        numLayers = max(numLayers,pdsch.NumLayers);
    end
    [Ns,P] = size(pdschEqSymbols);
    pdschEqSym = zeros(Ns,maxNumLayers);
    pdschSym = zeros(Ns,maxNumLayers);
    pdschEqSym(:,1:P) = pdschEqSymbols;    
    pdschSym(:,1:P) = pdschSymbols;
    evmPerSlot(nslot+1,:) = slotEVM(pdschSym,pdschEqSym);
    subplot(2,1,1);
    plot(0:(NSlots-1),evmPerSlot,'o-');
    xlabel('Slot number');
    ylabel('EVM (%)');
    legend("layer " + (1:numLayers),'Location','EastOutside');
    title('EVM per layer per slot');

    subplot(2,1,2);
    [k,~,p] = ind2sub(siz,pdschIndices);
    rbsubs = floor((k-1) / 12);
    NRB = siz(1) / 12;
    evmPerRB = NaN(NRB,maxNumLayers);
    for nu = 1:pdsch.NumLayers
        for rb = unique(rbsubs).'
            this = (rbsubs==rb & p==nu);
            evmPerRB(rb+1,nu) = rbEVM(pdschSym(this),pdschEqSym(this));
        end
    end

    plot(0:(NRB-1),evmPerRB,'x-');
    xlabel('Resource block');
    ylabel('EVM (%)');
    legend("layer " + (1:numLayers),'Location','EastOutside');
    title(['EVM per layer per resource block, slot #' num2str(nslot)]);
    
    drawnow;
    
end

function plotCQI(simParameters,CSIReport,perc)
% Plot CQI median and percentiles 

    % Calculate median and percentiles
    med = cellfun(@(x) median([x.CQI]), CSIReport);
    p1 = cellfun(@(x) prctile([x.CQI],50-perc/2), CSIReport);
    p2 = cellfun(@(x) prctile([x.CQI],50+perc/2), CSIReport);
    
    % Calculate the percentage of CQI not in the set {median CQI -1, median CQI, median CQI +1} 
    cqiPerc = cellfun(@(x,y) sum(abs([x.CQI]-y)>1)/length(x),CSIReport,num2cell(med));
    
    figure;
    subplot(211)
    errorbar(simParameters.SNRIn,med,p2-p1,'o-.')
    ylabel('CQI value')
    title(sprintf('Median CQI and (%g,%g) Percentiles',50-perc/2,50+perc/2));
    grid

    subplot(212)
    plot(simParameters.SNRIn,cqiPerc,'o-.')
    xlabel('SNR (dB)')
    ylabel('%')
    title('CQI not in set \{median CQI -1, median CQI, median CQI +1\}');
    grid   

end

function ranklimit=rankrestrictionfromRI(RI)
    if all(RI == 1)
        ranklimit = 0;
    else
        onesPositions = find(RI == 1);  
        ranklimit = strjoin(arrayfun(@num2str, onesPositions, 'UniformOutput', false), '');
    end
end
